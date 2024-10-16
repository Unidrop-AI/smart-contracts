// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./MetaFlapAirdropStorage.sol";

contract MetaFlapAirdrop is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    EIP712Upgradeable,
    IERC721ReceiverUpgradeable,
    ERC1155ReceiverUpgradeable,
    UUPSUpgradeable,
    MetaFlapAirdropStorage
{
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __AccessControl_init();
        __Pausable_init();
        __EIP712_init("Airdrop", "1");
        __ERC1155Receiver_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(WHITELIST_SETTER_ROLE, msg.sender);
        _grantRole(CLAIM_DELEGATOR_ROLE, msg.sender);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setWhitelistToken(
        address tokenAddress,
        bool whitelist
    ) external onlyRole(WHITELIST_SETTER_ROLE) {
        bool alreadyWhitelisted = whitelistTokens[tokenAddress] !=
            ContractType.NONE;

        if (whitelist) {
            require(!alreadyWhitelisted, "AlreadyWhitelistToken");

            ContractType tokenType = _untrustedDetectContractType(tokenAddress);
            require(
                tokenType == ContractType.ERC1155 ||
                    tokenType == ContractType.ERC721 ||
                    tokenType == ContractType.ERC20,
                "InvalidToken"
            );

            whitelistTokens[tokenAddress] = tokenType;
        } else {
            require(alreadyWhitelisted, "NonWhitelistToken");
            delete whitelistTokens[tokenAddress];
        }

        // event
        emit WhitelistToken({tokenAddress: tokenAddress, whitelist: whitelist});
    }

    function createCampaign(
        address tokenAddress,
        uint256 tokenId,
        uint256 tokenAmount,
        uint256 tokenAmountPerAccount,
        uint256 start,
        uint256 duration,
        uint256 claimDuration,
        string calldata data
    ) external whenNotPaused {
        // token must be whitelisted
        ContractType tokenType = whitelistTokens[tokenAddress];
        require(tokenType != ContractType.NONE, "NonWhitelistToken");

        require(tokenAmount > 0, "InvalidTokenAmount");
        require(tokenAmountPerAccount > 0, "InvalidTokenAmountPerAccount");
        require(
            tokenAmount % tokenAmountPerAccount == 0,
            "NonDivisibleTokenAmountPerAccount"
        );

        // solhint-disable-next-line not-rely-on-time
        require(start > block.timestamp, "PastStart");
        require(duration >= claimDuration, "DurationLessThanClaimDuration");
        require(claimDuration >= 7 days, "ClaimDurationMin7Days");

        // create campaign
        currentCampaignId.increment();
        uint256 campaignId = currentCampaignId.current();
        Campaign storage campaign = campaigns[campaignId];
        assert(campaign.owner == address(0));

        address owner = msg.sender;
        uint256 end = start + duration;
        uint256 claimStart = end - claimDuration;

        campaign.start = start;
        campaign.end = end;
        campaign.claimStart = claimStart;
        campaign.tokenId = tokenId;
        campaign.tokenAmount = tokenAmount;
        campaign.tokenAmountPerAccount = tokenAmountPerAccount;
        campaign.tokenType = tokenType;
        campaign.tokenAddress = tokenAddress;
        campaign.owner = owner;
        campaign.data = data;

        // NOTE: use "campaign.*" in the following statements to avoid this error:
        // CompilerError: Stack too deep, try removing local variables

        // transfer airdrop token from owner to contract
        _untrustedTransferTokenFrom(
            owner,
            address(this),
            tokenType,
            campaign.tokenAddress,
            campaign.tokenId,
            campaign.tokenAmount
        );

        // event
        emit CreateCampaign({
            id: campaignId,
            owner: owner,
            tokenAddress: campaign.tokenAddress,
            tokenType: tokenType,
            tokenId: campaign.tokenId,
            tokenAmount: campaign.tokenAmount,
            tokenAmountPerAccount: campaign.tokenAmountPerAccount,
            start: campaign.start,
            end: end,
            claimStart: claimStart,
            data: campaign.data
        });
    }

    function cancelCampaign(uint256 id) external {
        // verify campaign
        address owner = msg.sender;
        Campaign storage campaign = campaigns[id];
        require(campaign.owner == owner, "NonOwner");

        // solhint-disable-next-line not-rely-on-time
        require(campaign.start > block.timestamp, "TooLate");

        uint256 tokenId = campaign.tokenId;
        uint256 tokenAmount = campaign.tokenAmount;
        ContractType tokenType = campaign.tokenType;
        address tokenAddress = campaign.tokenAddress;

        delete campaigns[id];

        // transfer airdrop token from contract to owner
        _untrustedTransferTokenFrom(
            address(this),
            owner,
            tokenType,
            tokenAddress,
            tokenId,
            tokenAmount
        );

        // event
        emit CancelCampaign({id: id});
    }

    function finalizeCampaign(uint256 id) external {
        // verify campaign
        address owner = msg.sender;
        Campaign storage campaign = campaigns[id];
        require(campaign.owner == owner, "NonOwner");

        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp > campaign.end, "TooEarly");

        uint256 remainingTokenAmount = campaign.tokenAmount -
            campaign.claimedTokenAmount;
        require(remainingTokenAmount > 0, "NoRemainingTokenAmount");

        uint256 tokenId = campaign.tokenId;
        ContractType tokenType = campaign.tokenType;
        address tokenAddress = campaign.tokenAddress;

        delete campaigns[id];

        // transfer airdrop token from contract to owner
        _untrustedTransferTokenFrom(
            address(this),
            owner,
            tokenType,
            tokenAddress,
            tokenId,
            remainingTokenAmount
        );

        // event
        emit FinalizeCampaign({
            id: id,
            remainingTokenAmount: remainingTokenAmount
        });
    }

    function claim(
        uint256 campaignId,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external whenNotPaused {
        Campaign storage campaign = campaigns[campaignId];
        require(campaign.owner != address(0), "NonExistentCampaign");

        address beneficiary = msg.sender;
        require(!claimed[campaignId][beneficiary], "AlreadyClaimed");

        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp >= campaign.claimStart, "TooEarly");

        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp <= campaign.end, "TooLate");

        // verify signature
        bytes32 structHash = keccak256(
            abi.encode(_CLAIM_TYPEHASH, campaignId, beneficiary)
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSAUpgradeable.recover(hash, v, r, s);
        require(hasRole(CLAIM_DELEGATOR_ROLE, signer), "Forbidden");

        // mark claimed
        claimed[campaignId][beneficiary] = true;
        uint256 claimedTokenAmount = campaign.tokenAmountPerAccount;
        campaign.claimedTokenAmount += claimedTokenAmount;
        assert(campaign.claimedTokenAmount <= campaign.tokenAmount);

        // transfer airdrop token from contract to beneficiary
        _untrustedTransferTokenFrom(
            address(this),
            beneficiary,
            campaign.tokenType,
            campaign.tokenAddress,
            campaign.tokenId,
            claimedTokenAmount
        );

        emit Claim({beneficiary: beneficiary, campaignId: campaignId});
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        // token must be whitelisted
        address tokenAddress = msg.sender;
        ContractType tokenType = whitelistTokens[tokenAddress];
        require(tokenType != ContractType.NONE, "NonWhitelistToken");

        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        // token must be whitelisted
        address tokenAddress = msg.sender;
        ContractType tokenType = whitelistTokens[tokenAddress];
        require(tokenType != ContractType.NONE, "NonWhitelistToken");

        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        // return this.onERC1155BatchReceived.selector;
        return "";
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC1155ReceiverUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {} // solhint-disable-line no-empty-blocks

    function _untrustedTransferTokenFrom(
        address from,
        address to,
        ContractType tokenType,
        address tokenAddress,
        uint256 tokenId,
        uint256 tokenAmount
    ) private {
        if (tokenType == ContractType.ERC1155) {
            return
                IERC1155Upgradeable(tokenAddress).safeTransferFrom(
                    from,
                    to,
                    tokenId,
                    tokenAmount,
                    ""
                );
        }

        if (tokenType == ContractType.ERC721) {
            require(tokenAmount == 1, "InsufficientTokens");
            return
                IERC721Upgradeable(tokenAddress).safeTransferFrom(
                    from,
                    to,
                    tokenId
                );
        }

        if (tokenType == ContractType.ERC20) {
            require(tokenId == 0, "NonZeroTokenIdERC20");
            return
                from == address(this)
                    ? SafeERC20Upgradeable.safeTransfer(
                        IERC20Upgradeable(tokenAddress),
                        to,
                        tokenAmount
                    )
                    : SafeERC20Upgradeable.safeTransferFrom(
                        IERC20Upgradeable(tokenAddress),
                        from,
                        to,
                        tokenAmount
                    );
        }

        revert("InvalidToken");
    }

    function _untrustedDetectContractType(
        address contractAddress
    ) private view returns (ContractType) {
        if (contractAddress.isContract()) {
            try
                IERC1155Upgradeable(contractAddress).supportsInterface(
                    ERC1155_INTERFACE
                )
            returns (bool supported) {
                if (supported) {
                    return ContractType.ERC1155;
                }
            } catch {} // solhint-disable-line no-empty-blocks

            try
                IERC721Upgradeable(contractAddress).supportsInterface(
                    ERC721_INTERFACE
                )
            returns (bool supported) {
                if (supported) {
                    return ContractType.ERC721;
                }
            } catch {} // solhint-disable-line no-empty-blocks

            try IERC20Upgradeable(contractAddress).totalSupply() returns (
                uint256 totalSupply
            ) {
                if (totalSupply > 0) {
                    return ContractType.ERC20;
                }
            } catch {} // solhint-disable-line no-empty-blocks
        }

        return ContractType.NONE;
    }
}

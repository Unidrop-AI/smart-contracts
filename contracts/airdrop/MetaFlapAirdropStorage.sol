// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

abstract contract MetaFlapAirdropStorage {
    enum ContractType {
        NONE,
        ERC721,
        ERC1155,
        ERC20
    }

    struct Campaign {
        uint256 start;
        uint256 end;
        uint256 claimStart;
        uint256 tokenId;
        uint256 tokenAmount;
        uint256 tokenAmountPerAccount;
        uint256 claimedTokenAmount;
        ContractType tokenType;
        address tokenAddress;
        address owner;
        string data;
    }

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant WHITELIST_SETTER_ROLE =
        keccak256("WHITELIST_SETTER_ROLE");
    bytes32 public constant CLAIM_DELEGATOR_ROLE =
        keccak256("CLAIM_DELEGATOR_ROLE");

    bytes4 public constant ERC721_INTERFACE = 0x80ac58cd;
    bytes4 public constant ERC1155_INTERFACE = 0xd9b67a26;

    // tokenAddress => contractType
    mapping(address => ContractType) public whitelistTokens;

    // incremental campaign
    CountersUpgradeable.Counter public currentCampaignId;

    mapping(uint256 => Campaign) public campaigns;

    // campaignId => beneficiaryAddress => isClaimed
    mapping(uint256 => mapping(address => bool)) public claimed;

    bytes32 internal constant _CLAIM_TYPEHASH =
        keccak256("Claim(uint256 campaignId,address beneficiary)");

    event WhitelistToken(address indexed tokenAddress, bool whitelist);

    event CreateCampaign(
        uint256 indexed id,
        address indexed owner,
        address indexed tokenAddress,
        ContractType tokenType,
        uint256 tokenId,
        uint256 tokenAmount,
        uint256 tokenAmountPerAccount,
        uint256 start,
        uint256 end,
        uint256 claimStart,
        string data
    );

    event CancelCampaign(uint256 indexed id);

    event FinalizeCampaign(uint256 indexed id, uint256 remainingTokenAmount);

    event Claim(uint256 indexed campaignId, address indexed beneficiary);
}

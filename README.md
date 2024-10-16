# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.js
```

```
npx hardhat compile

npx hardhat run --network testnet scripts/deploy.mtf.js

npx hardhat  verify --network testnet 0x1815d88002997EEAFA3657c69D7a7E4Fc1Be1dF3
```

# Local development

```
npx hardhat run --network localhost scripts/init.test.js
```

Console `npx hardhat console --network localhost`

```
> c = await hre.ethers.getContractAt('MetaStrike', '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512')
> c = await hre.ethers.getContractAt('MetaFlapAirdrop', '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9')
```

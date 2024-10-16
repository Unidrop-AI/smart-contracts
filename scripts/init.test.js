const deployAirdrop = require("./deploy.airdrop").main;
const deployMetaflap = require("./deploy.mtf").main;
const deployMarketplace = require("./deploy.market").main;

async function deployMts() {
  const Token = await ethers.getContractFactory("MetaStrike");
  const token = await Token.deploy();
  console.log("MetaStrike address:", token.target);
  return token.target;
}

async function createAirdrop(mtsAddress, airdropAddress) {
  const mtsContract = await ethers.getContractAt("MetaStrike", mtsAddress);
  const airdropContract = await ethers.getContractAt(
    "MetaFlapAirdrop",
    airdropAddress
  );

  const now = new Date();
  await mtsContract.approve(airdropAddress, BigInt(100) * BigInt(10 ** 18));
  await airdropContract.createCampaign(
    mtsAddress,
    0,
    BigInt(100) * BigInt(10 ** 18),
    BigInt(10) * BigInt(10 ** 18),
    BigInt(Math.floor(now / 1000) + 10),
    BigInt(10 * 86400),
    BigInt(9 * 86400),
    JSON.stringify({
      name: "Test",
      image: "https://postimg.cc/hhQ6DHSx",
    })
  );
}

async function main() {
  await deployMetaflap();
  const mtsAddress = await deployMts();
  const airdropAddress = await deployAirdrop();
  await deployMarketplace();

  const airdropContract = await ethers.getContractAt(
    "MetaFlapAirdrop",
    airdropAddress
  );
  await airdropContract.setWhitelistToken(mtsAddress, true);

  const mtsContract = await ethers.getContractAt("MetaStrike", mtsAddress);
  await mtsContract.transfer(
    "0x48A55815e4DF3c20dB7f870b0564448a6bD808C2",
    BigInt(100000) * BigInt(10 ** 18)
  );

  await createAirdrop(mtsAddress, airdropAddress);
}

// createAirdrop(
//   "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
//   "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"
// )
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

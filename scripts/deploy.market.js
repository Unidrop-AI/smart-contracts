async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying MetaMarketplace contract with the account:",
    deployer.address
  );

  //   console.log("Account balance:", (await deployer.getBalance()).toString());

  const Token = await ethers.getContractFactory("MetaMarketplace"); //Replace with name of your smart contract
  const token = await Token.deploy();

  console.log("MetaMarketplace address:", token.target);
}

if (!module.parent) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

module.exports = { main };

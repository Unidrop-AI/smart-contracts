async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying MetaFlapAirdrop contract with the account:",
    deployer.address
  );

  //   console.log("Account balance:", (await deployer.getBalance()).toString());

  const Token = await ethers.getContractFactory("MetaFlapAirdrop"); //Replace with name of your smart contract
  const token = await upgrades.deployProxy(Token, [], {
    kind: "uups",
    initializer: "initialize",
  });
  await token.waitForDeployment();
  const address = await token.getAddress();
  console.log("MetaFlapAirdrop address:", address);
  return address;
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

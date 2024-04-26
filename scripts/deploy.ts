// @ts-ignore
import hardhat from 'hardhat';

async function deploy () {
  await hardhat.run('compile');
  const Contract = await hardhat.ethers.getContractFactory('Mover');
  const contract = await Contract.deploy();
  await contract.deployed();
  console.log(contract.address);
}

(async () => {
  try {
    await deploy();
    process.exit(0);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
})()

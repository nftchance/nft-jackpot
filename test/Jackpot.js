const { assert } = require('chai')

var chai = require('chai')
    .use(require('chai-as-promised'))
    .should()

const { ethers } = require("hardhat");

const { networkConfig } = require('../hardhat.helper')

describe("Jackpot", function () {
    before(async () => {
        [owner, address1] = await ethers.getSigners();

        // Handle Chainlink contracts
        // Coordinator
        // Link Token
        const _network = await ethers.getDefaultProvider().getNetwork();
        const chainId = _network.chainId;

        let vrfCoordinatorAddress;

        if (chainId != 31337) { // If it's not a local chain use the real address
            vrfCoordinatorAddress = networkConfig[chainId]['vrfCoordinator']
            linkAddress = networkConfig[chainId]['linkToken']
        } else {
            const { deployments, getNamedAccounts, network, ethers } = hre;
            const { deploy, execute } = deployments;
            const { deployer, linkToken, linkETHPriceFeed } = await getNamedAccounts();

            // If it's a local chain, deploy the contracts
            const vrfTx = await deploy("VRFCoordinatorV2TestHelper", {
                from: deployer,
                log: true,
                args: [linkToken, ethers.constants.AddressZero, linkETHPriceFeed],
                contract:
                    "contracts/test/VRFCoordinatorV2TestHelper.sol:VRFCoordinatorV2TestHelper",
            });

            vrfCoordinatorAddress = vrfTx.address;

            await execute(
                "VRFCoordinatorV2TestHelper",
                { from: deployer },
                "setConfig",
                3,
                2500000,
                86400,
                33285,
                "60000000000000000",
                {
                    fulfillmentFlatFeeLinkPPMTier1: 250000,
                    fulfillmentFlatFeeLinkPPMTier2: 250000,
                    fulfillmentFlatFeeLinkPPMTier3: 250000,
                    fulfillmentFlatFeeLinkPPMTier4: 250000,
                    fulfillmentFlatFeeLinkPPMTier5: 250000,
                    reqsForTier2: 0,
                    reqsForTier3: 0,
                    reqsForTier4: 0,
                    reqsForTier5: 0,
                }
            );
        }

        console.log("---------- ✅ Chainlink contracts deployed")

        await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [vrfCoordinatorAddress],
        });

        await (
            await ethers.getSigner(owner.address)
        ).sendTransaction({
            to: vrfCoordinatorAddress,
            value: ethers.utils.parseEther("100"),
        });

        console.log("---------- ✅ Chainlink impersonated")

        const masterPrizePool = await ethers.getContractFactory("JackpotPrizePool");
        masterPrizePoolContract = await masterPrizePool.deploy();
        masterPrizePoolContract = await masterPrizePoolContract.deployed();
        masterPrizePoolAddress = masterPrizePoolContract.address;

        const Jackpot = await ethers.getContractFactory("Jackpot");

        // Gas lane to be used for Randomness responses
        const keyHash = networkConfig[chainId]['keyHash']

        jackpot = await Jackpot.deploy(
            masterPrizePoolAddress,
            vrfCoordinatorAddress,
            linkAddress,
            keyHash
        );

        jackpot = await jackpot.deployed();

        console.log("---------- ✅ Jackpot contracts deployed")
    })

    describe('Master Prize Pool Deployment', async () => {
        it('Master Prize Pool contract deploys successfully.', async () => {
            const address = masterPrizePoolAddress
            assert.notEqual(address, '')
            assert.notEqual(address, 0x0)
            assert.notEqual(address, null)
            assert.notEqual(address, undefined)
        })
    });

    describe('Jackpot Deployment', async () => {
        it('Jackpot contract deploys successfully.', async () => {
            const address = jackpot.address
            assert.notEqual(address, '')
            assert.notEqual(address, 0x0)
            assert.notEqual(address, null)
            assert.notEqual(address, undefined)
        })

        it("Can set prize pool implementation", async () => {
            await jackpot.setPrizePoolImplementation(masterPrizePoolAddress);
            const prizePool = await jackpot.prizePoolImplementation();
            assert.equal(prizePool, masterPrizePoolAddress);
        })

        it("Cannot draw for non-initialized Prize Pool", async () => {
            const quantity = ethers.BigNumber.from(1);
            await jackpot.drawJackpot(quantity).should.be.revertedWith('JackpotComptroller::onlyPrizePool: Sender is not a Prize Pool.');
        })

        it("Cannot open Prize with no cancel time", async () => {
            const constants = {
                fingerprintDecayConstant: 0.0,
                priceInitial: 0.0,
                priceScaleConstant: 0.0,
                priceDecayConstant: 0.0,
                startTime: 0,
                cancelTime: 0,
                endTime: 0,
            }
            await jackpot.openJackpot(constants, [], []).should.be.revertedWith('Jackpot::openJackpot: cancel time must be in the future.');
        })

        it("Cannot open Prize Pool with no end time", async () => {
            // Get current block timestamp and add an hour 
            const block = await ethers.provider.getBlock();
            const timestamp = block.timestamp;
            const cancelTime = timestamp + 3600;

            const constants = {
                fingerprintDecayConstant: 0.0,
                priceInitial: 0.0,
                priceScaleConstant: 0.0,
                priceDecayConstant: 0.0,
                startTime: 0,
                cancelTime: `${cancelTime}`,
                endTime: 0,
            }
            await jackpot.openJackpot(constants, [], []).should.be.revertedWith('Jackpot::openJackpot: end time must be in the future.');
        })

        it("Cannot open Prize Pool with no collateral", async () => {
            // Get current block timestamp and add an hour 
            const block = await ethers.provider.getBlock();
            const timestamp = block.timestamp;
            const cancelTime = timestamp + 3600;
            const endTime = timestamp + 7200;

            const constants = {
                fingerprintDecayConstant: 0.0,
                priceInitial: 0.0,
                priceScaleConstant: 0.0,
                priceDecayConstant: 0.0,
                startTime: 0,
                cancelTime: `${cancelTime}`,
                endTime: `${endTime}`,
            }
            await jackpot.openJackpot(constants, [], []).should.be.revertedWith('Jackpot::openJackpot: collateral must be provided.');
        })

        it("Open Prize Pool with .02 ETH in collateral", async () => {
            // Get current block timestamp and add an hour 
            const block = await ethers.provider.getBlock();
            const timestamp = block.timestamp;
            const cancelTime = timestamp + 3600;
            const endTime = timestamp + 7200;

            const constants = {
                fingerprintDecayConstant: 0.0,
                priceInitial: 0.0,
                priceScaleConstant: 0.0,
                priceDecayConstant: 0.0,
                startTime: 0,
                cancelTime: `${cancelTime}`,
                endTime: `${endTime}`,
            }

            jackpotAddress = await jackpot.callStatic.openJackpot(constants, [], [], { value: ethers.utils.parseEther("0.02") });
            assert.notEqual(jackpotAddress, '')
            assert.notEqual(jackpotAddress, 0x0);
            assert.notEqual(jackpotAddress, null)
            assert.notEqual(jackpotAddress, undefined)
        })

    });
});

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
        const network = await ethers.getDefaultProvider().getNetwork();
        const chainId = network.chainId; 

        let vrfCoordinatorAddress;

        if (chainId != 31337) { // If it's not a local chain use the real address
            vrfCoordinatorAddress = networkConfig[chainId]['vrfCoordinator']
            linkAddress = networkConfig[chainId]['linkToken']
        } else {
            // If it's a local chain, deploy the contracts
            const vrfTx = await deploy("VRFCoordinatorV2TestHelper", {
                from: deployer,
                log: true,
                args: [linkAddress, blockHashStore, linkEthFeed],
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

        console.log("✅ Chainlink contracts deployed")

        const masterPrizePool = await ethers.getContractFactory("JackpotPrizePool");
        masterPrizePoolContract = await masterPrizePool.deploy();
        masterPrizePoolContract = await masterPrizePoolContract.deployed();
        masterPrizePoolAddress = masterPrizePoolContract.address;

        const Jackpot = await ethers.getContractFactory("Jackpot");

        // Gas lane to be used for Randomness responses
        const keyHash = networkConfig[chainId]['keyHash']

        console.log(masterPrizePoolAddress)
        console.log(vrfCoordinatorAddress)
        console.log(linkAddress)
        console.log(keyHash)

        jackpot = await Jackpot.deploy(
            masterPrizePoolAddress,
            vrfCoordinatorAddress,
            linkAddress,
            keyHash
        );

        jackpot = await jackpot.deployed();

        console.log("✅ Jackpot contracts deployed")
    })

    describe('Deployment', async () => {
        it('Jackpot contract deploys successfully.', async () => {
            const address = jackpot.address
            assert.notEqual(address, '')
            assert.notEqual(address, 0x0)
            assert.notEqual(address, null)
            assert.notEqual(address, undefined)
        })
    });
});

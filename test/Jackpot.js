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

        masterPrizePool = await ethers.getContractFactory("JackpotPrizePool");
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

        // Get current block timestamp and add an hour 
        block = await ethers.provider.getBlock();
        timestamp = block.timestamp;
        cancelTime = timestamp + 3600;
        endTime = timestamp + 7200;
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

        it("Can set prize pool implementation.", async () => {
            await jackpot.setPrizePoolImplementation(masterPrizePoolAddress);
            const prizePool = await jackpot.prizePoolImplementation();
            assert.equal(prizePool, masterPrizePoolAddress);
        })

        it("Cannot draw for non-initialized Prize Pool.", async () => {
            const quantity = ethers.BigNumber.from(1);
            await jackpot.drawJackpot(quantity).should.be.revertedWith('JackpotComptroller::onlyPrizePool: Sender is not a Prize Pool.');
        })

        it("Cannot open Prize with no cancel time.", async () => {
            const stateSchema = {
                started: false,
                status: 0,
                requiredQualifiers: 0,
                max: 0,
                cancelTime: 0.0,
                endTime: endTime,
                fingerprintDecay: 0.0,
            }

            const jackpotSchema = { 
                price: 0.0,
                state: 0.0,
                qualifiers: [],
                winners: [],
            }

            await jackpot.openJackpot(stateSchema, jackpotSchema).should.be.revertedWith('Jackpot::openJackpot: cancel time must be in the future.');
        })

        it("Cannot open Prize Pool with no end time.", async () => {
            const stateSchema = {
                started: false,
                status: 0,
                requiredQualifiers: 0,
                max: 0,
                cancelTime: cancelTime,
                endTime: 0.0,
                fingerprintDecay: 0.0,
            }

            const jackpotSchema = { 
                price: 0.0,
                state: 0.0,
                qualifiers: [],
                winners: [],
            }

            await jackpot.openJackpot(stateSchema, jackpotSchema).should.be.revertedWith('Jackpot::openJackpot: end time must be in the future.');
        })

        it("Can open prize pool", async () => { 
            const stateSchema = {
                started: false,
                status: 0,
                requiredQualifiers: 0,
                max: 0,
                cancelTime: cancelTime,
                endTime: endTime,
                fingerprintDecay: 0.0,
            }

            const jackpotSchema = { 
                price: 0.0,
                state: 0.0,
                qualifiers: [],
                winners: [],
            }

            await jackpot.openJackpot(stateSchema, jackpotSchema);
        });
    });

    // describe('Prize Pool Processing', async () => {
    //     // Prepare a prize pool for processing
    //     before(async () => {
    //         console.log("---------- 📝 Preparing prize pool for processing")

    //         // Get current block timestamp and add an hour 
    //         const block = await ethers.provider.getBlock();
    //         const timestamp = block.timestamp;
    //         const cancelTime = timestamp + 3600;
    //         const endTime = timestamp + 7200;

    //         const stateSchema = { 
    //             started: false,
    //             status: 0,
    //             requiredQualifiers: 0,
    //             max: 10,
    //             address: masterPrizePool.address,
    //             cancelTime: `${cancelTime}`,
    //             endTime: `${endTime}`,
    //             fingerPrintDecay: 0,
    //         }

    //         const jackpotSchema = { 
    //             price: 0,
    //             state: 0,
    //             qualifiers: [], 
    //             winners: [],
    //         }

    //         var tx = await jackpot.openJackpot(stateSchema, jackpotSchema, { value: ethers.utils.parseEther("0.02") });
    //         tx = await tx.wait()

    //         newPrizePool = masterPrizePool.attach(tx.events[tx.events.length - 1].address)
    //     });

    //     it("Cannot draw for initialized Prize Pool because end time has not been reached", async () => {
    //         await newPrizePool.drawJackpot().should.be.revertedWith("JackpotPrizePool::drawJackpot: entry period not over.");
    //     });

    //     it("Cannot buy entry before Prize Pool start time is reached", async () => { 
    //         await newPrizePool.openEntryEmpty(1).should.be.revertedWith("JackpotPrizePool::_openEntry: Jackpot has not started yet.");
    //     })

    //     it("Can set start time of Prize Pool", async () => { });

    //     it("Cannot change the start time of the Prize Pool", async () => { });

    //     it("Can set start time of Prize Pool", async () => { });
    // });
});
const { assert } = require('chai')

var chai = require('chai')
    .use(require('chai-as-promised'))
    .should()

const { ethers } = require("hardhat");

describe("Jackpot", function () {
    before(async () => {
        [owner, address1] = await ethers.getSigners();

        const Jackpot = await ethers.getContractFactory("contracts/Jackpot");

        const arguments = require('../scripts/arguments.js')
        jackpot = await Jackpot.deploy(
            ...arguments
        );

        jackpot = await jackpot.deployed();
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

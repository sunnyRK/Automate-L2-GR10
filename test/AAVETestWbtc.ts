import { getEnabledCategories } from "node:trace_events";

const { expect } = require("chai");
const { BigNumber, Wallet } = require("ethers");
const { formatEther, parseEther } =require('@ethersproject/units')
const daiAbi = require('../abis/daiAbi.json');
const strategyAbi = require('../artifacts/contracts/strategy.sol/strategy.json');
const hre = require("hardhat");

// // Mainnet Fork and test case for mainnet with hardhat network by impersonate account from mainnet
describe("deployed Contract on Mainnet fork", function() {
    let accounts: any
    let accountToImpersonate: any
    let wbtcAddress: any
    let wbtcContract: any
    let strategyContract: any
    let strategyContract_Instance: any
    let signer: any
    let impersonateBalanceBefore: any
    let ourAccountBalanceBefore: any
    let ourAccountBalanceAfter: any
    let maxValue: any
    let daiBalanceBefore: any
    let addressProvider: any
    let lendingAddressProvider: any
    let aWbtcAddress: any
    let WETH: any
    let wethContract: any

    describe('create functions', () => {
        before(async () => {
            maxValue = '115792089237316195423570985008687907853269984665640564039457584007913129639935'
            accounts = await hre.ethers.getSigners();

            // Mainnet addresses
            // accountToImpersonate = '0xF977814e90dA44bFA03b6295A0616a897441aceC' // Dai rich address
            accountToImpersonate = '0x56178a0d5F301bAf6CF3e1Cd53d9863437345Bf9' // WBTC rich address
            wbtcAddress = '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599' // WBTC
            aWbtcAddress = '0x9ff58f4fFB29fA2266Ab25e75e2A8b3503311656' 
            addressProvider = '0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5' // addressProvider mainnet
            WETH = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'

            // lendingAddressProvider = '0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5'

            // polygon
            // accountToImpersonate = '0x83D44916491B7a34b0EEc3B38204982dac36880B' // Dai rich address
            // wbtcAddress = '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063' // Dai contract
            // aDaiAddress = '0x27F8D03b3a2196956ED754baDc28D73be8830A6e' 
            // addressProvider = '0xd05e3E715d945B59290df0ae8eF85c1BdB684744' // addressProvider PolyGon

            await hre.network.provider.request({
                method: "hardhat_impersonateAccount",
                params: [accountToImpersonate]
            })
            signer = await hre.ethers.provider.getSigner(accountToImpersonate)

            wbtcContract = new hre.ethers.Contract(wbtcAddress, daiAbi, signer)
            wethContract = new hre.ethers.Contract(WETH, daiAbi, signer)

            impersonateBalanceBefore = await wbtcContract.balanceOf(accountToImpersonate)
            ourAccountBalanceBefore = await wbtcContract.balanceOf(accounts[0].address)

            await wbtcContract.transfer(accounts[0].address, impersonateBalanceBefore)
            await wethContract.transfer(accounts[0].address, hre.ethers.utils.parseUnits('1000', 18))

            signer = await hre.ethers.provider.getSigner(accounts[0].address)
            wbtcContract = new hre.ethers.Contract(wbtcAddress, daiAbi, signer)
            wethContract = new hre.ethers.Contract(WETH, daiAbi, signer)

            ourAccountBalanceAfter = await wbtcContract.balanceOf(accounts[0].address)

            console.log(impersonateBalanceBefore.toString())
            console.log(ourAccountBalanceAfter.toString())

            strategyContract = await hre.ethers.getContractFactory('strategy', signer);
            strategyContract_Instance = await strategyContract.deploy(wbtcAddress, aWbtcAddress, addressProvider);\

        });
        
        it("hardhat_impersonateAccount and check transfered balance to our account", async function() {
            await wethContract.transfer(strategyContract_Instance.address,  hre.ethers.utils.parseUnits('100', 18))
            await wbtcContract.approve(
                strategyContract_Instance.address, 
                maxValue
            );
            await strategyContract_Instance.depositInVault('100000000');
            await strategyContract_Instance.getBal()
            await strategyContract_Instance.flashLoan('0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2');
            await strategyContract_Instance.getBal()
        });
    });
});
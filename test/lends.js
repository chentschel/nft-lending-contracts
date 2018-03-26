const BigNumber = web3.BigNumber

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should()

const EVMRevert = 'VM Exception while processing transaction: revert'

const Lender = artifacts.require('Lender')
const Marketplace = artifacts.require('Marketplace')

const { increaseTime, duration } = require('./helpers/increaseTime')

function checkMintTx(log, addr, amount) {
  log.event.should.be.eq('Mint')
  log.args.to.should.be.equal(addr)
  log.args.amount.should.be.bignumber.equal(amount)
}

function checkTransferTx(log, to, amount) {
  log.event.should.be.eq('Transfer')
  log.args.to.should.be.equal(to)
  log.args.value.should.be.bignumber.equal(amount)
}

function checkBurnTx(log, burner, value) {
  log.event.should.be.eq('Burn')
  log.args.burner.should.be.equal(burner)
  log.args.value.should.be.bignumber.equal(value)
}

// Vote Events
function checkVoteTx(log, voter, lendRate, lendPercentage) {
  log.event.should.be.eq('Vote')
  log.args.voter.should.be.equal(voter)
  log.args.lendRate.should.be.bignumber.equal(lendRate)
  log.args.lendPercentage.should.be.bignumber.equal(lendPercentage)
}

function checkVoteClosedTx(log, sharesCount, lendRate, lendPercentage) {
  log.event.should.be.eq('VoteClosed')
  log.args.sharesCount.should.be.bignumber.equal(sharesCount)
  log.args.lendRate.should.be.bignumber.equal(lendRate)
  log.args.lendPercentage.should.be.bignumber.equal(lendPercentage)
}

contract('Lend', ([_, _owner, _backer_1, _backer_2, _lender, _seller, _buyer]) => {
  let endTime = web3.eth.getBlock('latest').timestamp + duration.minutes(5)
  let market
  let lender

  beforeEach(async () => {
    market = await Marketplace.deployed()
    lender = await Lender.deployed()
  })

  // Test on buying / selling tokens

  it('_backer_1 should buy 10ETH', async () => {
    let investAmount = web3.toWei(10, 'ether')

    const { logs } = await lender.buy({ value: investAmount, from: _backer_1 })

    // Event emitted
    logs.length.should.be.equal(2)

    checkMintTx(logs[0], _backer_1, investAmount)
    checkTransferTx(logs[1], _backer_1, investAmount)

    // Check data
    let s = await lender.balanceOf(_backer_1)
    s.should.be.bignumber.equal(investAmount)
  })

  it('_backer_1 should sell 50% of the tokens', async () => {
    let investAmount = web3.toWei(5, 'ether')

    const { logs } = await lender.sell(investAmount, { from: _backer_1 })

    logs.length.should.be.equal(1)

    checkBurnTx(logs[0], _backer_1, investAmount)

    let r = await lender.balanceOf(_backer_1)

    r.should.be.bignumber.equal(investAmount)
  })

  it('_backer_2 should buy 10ETH', async () => {
    let investAmount = web3.toWei(10, 'ether')

    await lender.buy({ value: investAmount, from: _backer_2 })
    let r = await lender.balanceOf(_backer_2)
   
    r.should.be.bignumber.equal(investAmount)
  })

  // Test Voting

  it('should let _backer_1 vote', async () => {
    let lendRate = await lender.lendingRate()
    let lendPercentage = await lender.lendPercentage()

    lendRate.should.be.bignumber.equal(500)
    lendPercentage.should.be.bignumber.equal(2500)

    const { logs } = await lender.voteLendingSettings(600, 2600, { from: _backer_1 })

    // Check Events
    logs.length.should.be.equal(1)

    checkVoteTx(logs[0], _backer_1, 600, 2600)
  })

  it('should fail to let _backer_1 vote (already voted)', async () => {
    await lender.voteLendingSettings(600, 2600, { from: _backer_1 })
      .should.be.rejectedWith(EVMRevert)
  })

  it('should fail to let _backer_2 vote (>50% change)', async () => {
    let lendRate = await lender.lendingRate()
    let lendPercentage = await lender.lendPercentage()

    lendRate.should.be.bignumber.equal(500)
    lendPercentage.should.be.bignumber.equal(2500)

    await lender.voteLendingSettings(100, 1000, { from: _backer_2 })
      .should.be.rejectedWith(EVMRevert)
  })

  it('should let _backer_2 vote', async () => {
    const votingOpen = await lender.isVotingOpen()
    votingOpen.should.be.equal(true)

    const { logs } = await lender.voteLendingSettings(600, 2600, { from: _backer_2 })

    let b1 = await lender.balanceOf(_backer_1)
    let b2 = await lender.balanceOf(_backer_2)

    // Check Events
    logs.length.should.be.equal(2)

    checkVoteTx(logs[0], _backer_2, 600, 2600)
    checkVoteClosedTx(logs[1], b1.add(b2), 577, 2577)
  })

})

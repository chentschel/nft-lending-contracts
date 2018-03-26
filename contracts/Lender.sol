pragma solidity ^0.4.19;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";

import "./Marketplace.sol";
import "./IERC721Base.sol";
import "./TBCOToken.sol";
import "./NonFungibleEscrow.sol";

contract Lender is NonFungibleEscrow, TBCOToken, Ownable {
	event Vote(address indexed voter, uint256 lendRate, uint256 lendPercentage);
	event VoteClosed(uint256 sharesCount, uint256 lendRate, uint256 lendPercentage);

	using SafeMath for uint256;

	struct Lend {
		uint256 id;

		uint256 amount;
		uint256 yearlyRate;
		uint256 lastUpdate;
		uint256 paybackAmount;
		
		uint256 assetId;
		address registry;
		address seller;
	}

	/* A mappinig for lender with money */
	mapping (address => Lend) lenders;
	uint256 lendersCount;

	Lend[] lendersArr;

	uint256 public lendingRate = 500; //5.00%
	uint256 public lendPercentage = 2500; // 25.00%

	uint256 releseableAmount;

	// Marketplace address
	Marketplace private marketplace;

	// Votes
	mapping (address => uint256) voters;

	uint256 avgVoteRate = lendingRate;
	uint256 avgVotePercentage = lendPercentage;

	uint256 totalVoteShares;
	uint256 lastVotedAt;

	function isVotingOpen() public view returns (bool) {
		return (now - lastVotedAt) >= 5 days;
	}

	function _voteWeight() internal view returns (uint256) {
		return balances[msg.sender].mul(10000).div(totalSupply_);
	}

	function voteLendingSettings(uint256 _lendRate, uint256 _lendPercentage) public {
		require(isVotingOpen());

		// If opened for more than 45 days, restart 
		// the poll again
		if ((now - lastVotedAt) > 35 days) {
			lastVotedAt = now - 5 days;
		}

		require(_lendRate <= 10000);
		require(_lendPercentage <= 10000);

		// Check no more than 50% change allowed
		uint256 halfRate = lendingRate.div(2);
		uint256 halfPerc = lendPercentage.div(2);
		
		require(_lendRate >= lendingRate.sub(halfRate));
		require(_lendRate <= lendingRate.add(halfRate));
		require(_lendPercentage >= lendPercentage.sub(halfPerc));
		require(_lendPercentage <= lendPercentage.add(halfPerc));

		uint256 _balance = balanceOf(msg.sender);
		
		// Check can participate
		require(_balance > 0);
		
		// Check has not voted this round
		require(voters[msg.sender] < lastVotedAt);

		// Mark the voter for this round
		voters[msg.sender] = lastVotedAt;

		avgVoteRate = SafeMath.add(
			avgVoteRate.mul( 10000 - _voteWeight() ), 
			_lendRate.mul( _voteWeight() )
		).div(10000);

		avgVotePercentage = SafeMath.add(
			avgVotePercentage.mul( 10000 - _voteWeight() ), 
			_lendPercentage.mul( _voteWeight() )
		).div(10000);

		totalVoteShares = totalVoteShares.add(_balance);

		emit Vote(msg.sender, _lendRate, _lendPercentage);

		// close and apply votes result if voted > 50%
		if (totalVoteShares > totalSupply().div(2)) {
			emit VoteClosed(totalVoteShares, avgVoteRate, avgVotePercentage);
			
			// Reset poll
			lastVotedAt = now;
			totalVoteShares = 0;
						
			// Set values 
			lendingRate = avgVoteRate;
			lendPercentage = avgVotePercentage;
		}
	}	

	function setMarketplace(address _address) public {
		require(_address != address(0));
		
		marketplace = Marketplace(_address);
	}

	function _maxLendAmount() private view returns (uint256) {
		return address(this).balance.mul(10000).div(lendPercentage);
	}

	function _getAmount(uint256 amount, uint256 lendRate) private pure returns (uint256) {
		return amount.add( amount.mul( lendRate ).div(10000) );
	}

	function addLender(address erc721, uint256 assetId) public payable {
		// Check not already lender
		require(lenders[msg.sender].registry == address(0));
	    
	    // Check item in escrow
	    require(isOnEscrow(erc721, assetId));

	    // Check we can cover this lend amount
	    Escrow memory e = _getEscrow(erc721, assetId);
	    
	    uint256 itemAmount = e.amountInWei;
	    require(itemAmount <= _maxLendAmount());
	            
	    // check can cover 1.5 % fee
	    uint lendFee = e.amountInWei.mul(15).div(1000);
	    
	    require(msg.value >= lendFee);

	    // Return money 
	    if (msg.value > lendFee) {
	        msg.sender.transfer(msg.value.sub(lendFee));
	    }

		Lend memory lender = Lend({
			id: lendersCount,
			
			amount: itemAmount,
			yearlyRate: lendingRate,
			paybackAmount: _getAmount(itemAmount, lendingRate),
			lastUpdate: now,

			assetId: assetId,
			registry: erc721,
			seller: e.escrower
		});

		lenders[msg.sender] = lender;
		lendersArr.push(lender);

		lendersCount++;

		// transfer old owner full price of the item.
	    e.escrower.transfer(itemAmount);

	    // Remove Item from escrow list 
	    _removeEscrow(erc721, assetId);
	}

	function payLend() public payable {
		require(lenders[msg.sender].registry != address(0));
		require(msg.value > 0);

		Lend storage l = lenders[msg.sender];

		l.paybackAmount.sub(msg.value);
		l.lastUpdate = now;

		// Canceled all debt
		if (l.paybackAmount == 0) {
			IERC721Base dar = IERC721Base(l.registry);
			
			dar.safeTransferFrom(this, msg.sender, l.assetId);

			// Delete from array
			lendersArr[l.id] = lendersArr[lendersArr.length - 1];
			lendersArr.length = lendersArr.length - 1;

			delete lenders[msg.sender];
		}
	}

	function executeDebts() public {
		require(balanceOf(msg.sender) > 0);

		for (uint x = 0; x < lendersArr.length; x++) {

			Lend storage l = lendersArr[x];

			if ((now - l.lastUpdate) > 35 days) {

				IERC721Base dar = IERC721Base(l.registry);
		
				// Check we can sell the item 
				if (dar.isApprovedForAll(marketplace, this) == false) {
					dar.setApprovalForAll(marketplace, true);
				}

				marketplace.createOrder(
					l.registry, l.assetId, l.paybackAmount
				);

				// Delete from array

				lendersArr[x] = lendersArr[lendersArr.length - 1];
				lendersArr.length = lendersArr.length - 1;

				delete lenders[msg.sender];
			}
		}
	}
}
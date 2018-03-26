pragma solidity ^0.4.21;

import "./IERC721Base.sol";

contract NonFungibleEscrow {
	
	struct Escrow {
		address escrower;
		uint256 timestamp;
		uint256 amountInWei;
	}

	mapping (address => mapping (uint256 => Escrow)) private _escrows;

	function escrowAsset(address erc721, uint256 assetId, uint256 amountInWei) public {
		require(_escrows[erc721][assetId].escrower == address(0));

		IERC721Base dar = IERC721Base(erc721);

		require(dar.isAuthorized(this, assetId));
		require(dar.isAuthorized(msg.sender, assetId));

		// Transfer ownership
		dar.safeTransferFrom(msg.sender, address(this), assetId);

		_escrows[erc721][assetId] = Escrow({
			escrower: msg.sender,
			amountInWei: amountInWei,
			timestamp: now
		});
	}

	function cancelEscrow(address erc721, uint256 assetId) public {
		require(_escrows[erc721][assetId].escrower == msg.sender);

		IERC721Base dar = IERC721Base(erc721);
		dar.safeTransferFrom(this, msg.sender, assetId);

		_removeEscrow(erc721, assetId);
	}

	function _removeEscrow(address erc721, uint256 assetId) internal {
		delete _escrows[erc721][assetId];
	}

	function _getEscrow(address erc721, uint256 assetId) internal view returns (Escrow) {
		return _escrows[erc721][assetId];
	}

	function isOnEscrow(address erc721, uint256 assetId) public view returns (bool) {
		return _escrows[erc721][assetId].escrower != address(0);
	}
}
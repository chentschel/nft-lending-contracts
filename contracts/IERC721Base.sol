pragma solidity ^0.4.21;

/**
 * @title Interface for contracts conforming to ERC-721
 */
interface IERC721Base {
  function ownerOf(uint256 assetId) external view returns (address);
  function setApprovalForAll(address operator, bool authorized) external;
  function safeTransferFrom(address from, address to, uint256 assetId) external;
  function isAuthorized(address operator, uint256 assetId) external view returns (bool);
  function isApprovedForAll(address operator, address assetOwner) external view returns (bool);
}
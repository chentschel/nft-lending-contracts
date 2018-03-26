pragma solidity ^0.4.19;

/**
 * @title Interface for contracts conforming to ERC-721
 */
interface IERC721Base {
    function ownerOf(uint256 assetId) public view returns (address);
    function setApprovalForAll(address operator, bool authorized) public;
    function safeTransferFrom(address from, address to, uint256 assetId) public;
    function isAuthorized(address operator, uint256 assetId) public view returns (bool);
    function isApprovedForAll(address operator, address assetOwner) public view returns (bool);
}
pragma solidity 0.4.19;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "zeppelin-solidity/contracts/lifecycle/Destructible.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";

import "./IERC721Base.sol";

/* Based on https://github.com/decentralanc/marketplace-contracts/contracts/marketplace/Marketplace.sol */

contract Marketplace is Ownable, Pausable, Destructible {
    using SafeMath for uint256;

    struct Auction {
        // asset id
        uint256 assetId;
        // NFT registry
        address registry;
        // Owner of the NFT
        address seller;
        // Price (in wei) for the published item
        uint256 price;
    }

    mapping (bytes32 => Auction) auctionsById;
    uint256 totalAuctions;

    uint256 public ownerCutPercentage;
    uint256 public publicationFeeInWei;

    /* EVENTS */
    event AuctionCreated(
        bytes32 indexed id,
        address indexed registry,
        uint256 assetId,
        address indexed seller, 
        uint256 priceInWei
    );
    event AuctionSuccessful(
        bytes32 indexed id,
        address indexed registry,
        uint256 assetId, 
        address indexed seller, 
        uint256 totalPrice, 
        address winner
    );
    event AuctionCancelled(
        bytes32 indexed id,
        address indexed registry,
        uint256 assetId, 
        address indexed seller
    );

    event ChangedPublicationFee(uint256 publicationFee);
    event ChangedOwnerCut(uint256 ownerCut);

    /**
     * @dev Sets the publication fee that's charged to users to publish items
     * @param publicationFee - Fee amount in wei this contract charges to publish an item
     */
    function setPublicationFee(uint256 publicationFee) onlyOwner public {
        publicationFeeInWei = publicationFee;

        ChangedPublicationFee(publicationFeeInWei);
    }

    /**
     * @dev Sets the share cut for the owner of the contract that's
     *  charged to the seller on a successful sale.
     * @param ownerCut - Share amount, from 0 to 100
     */
    function setOwnerCut(uint8 ownerCut) onlyOwner public {
        require(ownerCut < 100);

        ownerCutPercentage = ownerCut;

        ChangedOwnerCut(ownerCutPercentage);
    }

    /**
     * @dev Cancel an already published order
     * @param registry - address of the erc721 registry
     * @param assetId - ID of the published NFT
     * @param priceInWei - Price in Wei for the supported coin.
     */
    function createOrder(address registry, uint256 assetId, uint256 priceInWei) public whenNotPaused {
        IERC721Base dar = IERC721Base(registry);

        address assetOwner = dar.ownerOf(assetId);
        
        require(msg.sender == assetOwner);
        require(dar.isAuthorized(address(this), assetId));
        require(priceInWei > 0);

        bytes32 auctionId = keccak256(registry, assetId);

        auctionsById[auctionId] = Auction({
            assetId: assetId,
            registry: registry,
            seller: assetOwner,
            price: priceInWei
        });

        // Check if there's a publication fee and
        // transfer the amount to marketplace owner.
        if (publicationFeeInWei > 0) {
            owner.transfer(publicationFeeInWei);
        }

        totalAuctions++;

        AuctionCreated(auctionId, registry, assetId, assetOwner, priceInWei);
    }

    /**
     * @dev Cancel an already published order
     *  can only be canceled by seller or the contract owner.
     * @param assetId - ID of the published NFT
     */
    function cancelOrder(address registry, uint256 assetId) public whenNotPaused {
        bytes32 auctionId = keccak256(registry, assetId);
        address seller = auctionsById[auctionId].seller;
        
        require(msg.sender == seller || msg.sender == owner);

        delete auctionsById[auctionId];
        totalAuctions--;

        AuctionCancelled(auctionId, registry, assetId, seller);
    }

    /**
     * @dev Executes the sale for a published NTF
     * @param assetId - ID of the published NFT
     */
    function executeOrder(address registry, uint256 assetId, uint256 price) public whenNotPaused {
        bytes32 auctionId = keccak256(registry, assetId);

        address seller = auctionsById[auctionId].seller;

        require(seller != address(0));
        require(seller != msg.sender);
        require(auctionsById[auctionId].price == price);

        IERC721Base dar = IERC721Base(registry);

        require(seller == dar.ownerOf(assetId));

        uint saleShareAmount = 0;

        if (ownerCutPercentage > 0) {
            // Calculate sale share
            saleShareAmount = price.mul(ownerCutPercentage).div(100);

            // Transfer share amount for marketplace Owner.
            owner.transfer(saleShareAmount);
        }

        // Transfer sale amount to seller
        seller.transfer( price.sub(saleShareAmount) );

        // Transfer asset owner
        dar.safeTransferFrom(seller, msg.sender, assetId);

        // Remove
        delete auctionsById[auctionId];
        totalAuctions--;

        AuctionSuccessful(auctionId, registry, assetId, seller, price, msg.sender);
    }
 }

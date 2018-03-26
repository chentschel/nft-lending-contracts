# nft-lending-contracts [![Build Status](https://travis-ci.org/chentschel/nft-lending-contracts.svg?branch=master)](https://travis-ci.org/chentschel/nft-lending-contracts)

Crowfunded Lending Contracts for buying ERC721. 

The main idea is that you can borrow money from a crowd-backed contract for buying any ERC721 compatible token. 

- The buyer provides a 'DAR' and assetId he wants to buy 
- Seller puts the item on escrow
- Buyer requires a loan and, if approved, this contract will buy the item at the escrowed price.
- Buyer pays the loan amount that's the item amount + IRR. 
- If the buyer don't pay after 35 days, any backer of the platform can execute the debt.
- Executing the debt means the lender looses his paid money and ownership of the item and the ERC721 will be published on a secondary ERC721 markerplace at a discounted price, for anyone to buy it.


pragma solidity ^0.4.19;

import "zeppelin-solidity/contracts/token/ERC20/StandardToken.sol";

/**
 * @title PataconToken
 */
contract TBCOToken is StandardToken {

  event Mint(address indexed to, uint256 amount);
  event Burn(address indexed burner, uint256 value);

  string public constant name = "TBCO Coin"; // solium-disable-line uppercase
  string public constant symbol = "TBCO"; // solium-disable-line uppercase
  uint8 public constant decimals = 18; // solium-disable-line uppercase

  function buy() payable public {
    require(msg.value > 0);

    uint _amount = msg.value;
    address _to = msg.sender;

    totalSupply_ = totalSupply_.add(_amount);
    balances[_to] = balances[_to].add(_amount);
    
    Mint(_to, _amount);
    Transfer(address(0), _to, _amount);
  }

  function sell(uint256 _value) public {
    require(_value <= balances[msg.sender]);

    address burner = msg.sender;

    balances[burner] = balances[burner].sub(_value);
    totalSupply_ = totalSupply_.sub(_value);
    
    burner.transfer(_value);

    Burn(burner, _value);
  }

}


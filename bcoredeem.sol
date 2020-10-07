pragma solidity >=0.4.22 <0.7.0;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

interface BCOExtendedToken {
    function burn(uint burnAmount) external;
    function transferFrom(address _from, address _to, uint _value) external returns (bool success);
    function balanceOf(address who) external returns (uint);
    function approve(address _spender, uint _value) external returns (bool success);
    function allowance(address _owner, address _spender) external returns (uint remaining);
}

interface TetherToken {
     function transfer(address _to, uint _value) external;
     function balanceOf(address who) external constant returns (uint);
}


/**
 * 
 */
contract BCORedeem {
    using SafeMath for uint;
    
    BCOExtendedToken bcoContract = BCOExtendedToken(0x08ECa7A3b77664381B1C96f8657dE24bf1e307E5);
    TetherToken tetherTokenContract = TetherToken(0x3096e8581d08e01FBC813C2603EB6e10268A76D7);
    address private owner;
    uint private price;   // цена выкупа в центах (0.01$)
    
    constructor() public {
        owner = msg.sender;
    }

    /**
     * 
     */
    function redeem() external returns (address bcoBurnerAddress) {
        
        require(bcoContract.balanceOf(msg.sender) != 0);
        require(tetherTokenContract.balanceOf(address(this)) != 0);
        
        
    }
    
    modifier onlyOwner() {
        if(msg.sender != owner) revert();
        _;
    }
    
    /**
     * Функция смены владельца контракта
     * @param _newOwner новый владелец
     */
    function setOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }
    
    function setPrice(uint _price) public onlyOwner {
        price = _price;
    }
    
    function getPrice() public returns(uint price) {
        return price;
    }
    
}
pragma solidity >=0.4.25 <0.7.0;

library SafeMath {
    function mul(uint a, uint b) internal pure returns (uint) {
        if (a == 0) {
            return 0;
        }
        uint c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint a, uint b) internal pure returns (uint) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint a, uint b) internal pure returns (uint) {
        assert(b <= a);
        return a - b;
    }

    function add(uint a, uint b) internal pure returns (uint) {
        uint c = a + b;
        assert(c >= a);
        return c;
    }
}

interface BCOExtendedToken {
    function burn(uint burnAmount) external;
    function transfer(address _to, uint _value) external returns (bool success);
    function balanceOf(address who) external returns (uint);
    function approve(address _spender, uint _value) external returns (bool success);
    function allowance(address _owner, address _spender) external returns (uint remaining);
}

interface TetherToken {
     function transfer(address _to, uint _value) external;
     function balanceOf(address who) external returns (uint);
}


/**
 * Копит USDT. При поступлении BCO, сжигает BCO и возвращает USDT, на адрес отправителя.
 */
contract BCORedeem {
    using SafeMath for uint;
    
    BCOExtendedToken private bcoContract;
    TetherToken private tetherTokenContract;
    address private owner;
    address private bcoContractAddress = 0x08ECa7A3b77664381B1C96f8657dE24bf1e307E5;
    address private tetherTokenContractAddress = 0x3096e8581d08e01FBC813C2603EB6e10268A76D7;
    uint private price;   // цена выкупа в центах (0.01$)
    
    constructor(uint _price) public {
        owner = msg.sender;
        price = _price;
        bcoContract = BCOExtendedToken(bcoContractAddress);
        tetherTokenContract = TetherToken(tetherTokenContractAddress);
    }

    /**
     * Вызывается функцией transfer при переводе BCO на адрес контракта.
     * Работает если на контракте баланс USDT > 0, и функцию вызывает контракт BCO.
     * Если баланс USDT меньше, чем получено BCO, то сжигает BCO и возвращает USDT в объёме остатка USDT на контракте.
     * Остаток BCO возвращает обратно отправителю.
     */
    function tokenFallback(address _to, uint _value) external {
        
        require(msg.sender == bcoContractAddress);
        require(tetherTokenContract.balanceOf(address(this)) != 0);

        uint _tempVar = SafeMath.mul(_value, price);  
        uint _usdtForTransfer = SafeMath.div(_tempVar, 10000);
        if(_usdtForTransfer > tetherTokenContract.balanceOf(address(this))) {
            _usdtForTransfer = tetherTokenContract.balanceOf(address(this));
            _tempVar = SafeMath.mul(_usdtForTransfer, 10000);
            uint _bcoForBurn = SafeMath.div(_tempVar, price);
            bcoContract.burn(_bcoForBurn);
            uint _bcoForReturn = SafeMath.sub(_value, _bcoForBurn);
            bcoContract.transfer(_to, _bcoForReturn);
            tetherTokenContract.transfer(_to, _usdtForTransfer);
        } else {
            bcoContract.burn(_value);
            tetherTokenContract.transfer(_to, _usdtForTransfer);
        }
        
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
    
    /**
     * Задаёт значение цены выкупа в центах
     */
    function setPrice(uint _price) public onlyOwner {
        price = _price;
    }
    
    /**
     * Возвращает значение цены выкупа в центах
     */
    function getPrice() public view returns (uint _price) {
        return price;
    }
    
}
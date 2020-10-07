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
 * Переводит BCO с вызывающего адреса на свой адрес, сжигает и отправляет USDT на вызывающий адрес
 */
contract BCORedeem {
    using SafeMath for uint;
    
    BCOExtendedToken private bcoContract;
    TetherToken private tetherTokenContract;
    address private owner;
    uint private price;   // цена выкупа в центах (0.01$)
    
    constructor(uint _price) public {
        owner = msg.sender;
        price = _price;
        bcoContract = BCOExtendedToken(0x08ECa7A3b77664381B1C96f8657dE24bf1e307E5);
        tetherTokenContract = TetherToken(0x3096e8581d08e01FBC813C2603EB6e10268A76D7);
    }

    /**
     * Функция работает если на вызывающем адресе есть BCO, весь баланс BCO этого адреса доступен
     * для вывода на контракт и на балансе контракта есть USDT.
     * Выводит BCO с вызывающего адреса на адрес контракта, сжигает и отправляет USDT на вызывающий адрес.
     */
    function redeem() external returns (bool success) {
        
        require(bcoContract.balanceOf(msg.sender) != 0);
        require(bcoContract.allowance(msg.sender, address(this)) == bcoContract.balanceOf(msg.sender));
        require(tetherTokenContract.balanceOf(address(this)) != 0);
        
        uint _usdtForTransfer = SafeMath.div(SafeMath.mul(bcoContract.balanceOf(msg.sender), price), 100);
        
        if(_usdtForTransfer < tetherTokenContract.balanceOf(address(this))) {
            _usdtForTransfer = tetherTokenContract.balanceOf(address(this));
        }
        uint _bcoForBurn = SafeMath.sub(SafeMath.mul(_usdtForTransfer, 100), price);
        bool _transfer = bcoContract.transferFrom(msg.sender, address(this), _bcoForBurn);
        if(_transfer) {
            bcoContract.burn(_bcoForBurn);
            tetherTokenContract.transfer(msg.sender, _usdtForTransfer);
        }
        
        return true;
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
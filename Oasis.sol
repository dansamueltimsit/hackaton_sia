// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


contract Oasis{


    uint256  public constant    MAX_SCORE       = 2**16;
    uint256  public constant    MAX_UINT_32     = 2**32-1;
    uint256 public constant     ticketPrice     = 100;
    
    
    uint256 public constant MAX_UINT256 = 2**256 - 1;
    
    uint32 public keyCounter = 0;
    //Data stuctures
    struct Key
    {
        uint32      id;
        string      message;
        address     publicKey;
        uint32      nbFound;
        uint32      nbActivated;
    }
    
    uint public playerCount;
    uint public playerFinishedCount;
    
    mapping(address => bool) public playerFinished;
    mapping(bytes32 => address) internal requests;
    
    event KeyFound(address indexed _player, uint _keyId);
    event RewardClaimed(address indexed _player, uint value);


    struct Player
    {
        uint256     currentOasisDeadline;
        bytes32     currentTicket;
        uint8       currentKeyIndex;
        uint256     earnedShells;
        uint8       state;
    }
    
    IERC20 public shellToken;
    
    address payable public owner;
    address public shellHolder;
    bool public open = false;
    
    //Scavenger Oasis parameters
    uint256 public OasisDuration = 3 hours;
    
    mapping(address => Player) public players;
    
    mapping(uint32 => Key) public keys;
    
    mapping(address => bool) public whiteList;
    bool    public whitelistNeeded = true;
    
    bytes32 internal keyHash;
    uint256 internal fee;
    uint8   public shareLockedPercent = 70;
    uint    public maxReward = 100000 * 10 ** 18; //1000 ISH ~ 5$
    uint8[5] public rewards = [0, 0, 0, 0, 0];
    
    constructor(address _token,  address _shellHolder){
        
        shellToken = IERC20(_token);
        shellHolder = _shellHolder;
        
        registerKey(0xe21f25B8C6971D62bFD1569F70B4996EB2B307cF, "Key message 1");
        registerKey(0x186bE1750c09EF8A34A47eE474019F5C09c91097, "Key message 2");
        registerKey(0x72734D1A68514bDA7cc319AcEa733cdAEFe77298, "Key message 3");
        registerKey(0xB7fdFB7DC59447db7749452275B523aD2981B55C, "Key message 4");
        
        owner = payable(msg.sender);
    }
    
    function registerKey(address publicKey, string memory message)
    internal
    {
        keys[keyCounter].publicKey      =   publicKey;
        keys[keyCounter].message        =   message;
        keyCounter += 1;
    }
    
    function startNewOasis()
    external returns(bytes32 ticket)
    {
        require(whiteList[msg.sender] == true || !whitelistNeeded);
        require(open, "The Oasis has not started");
        
        Player storage player = players[msg.sender];
    
        if(player.currentTicket == "0x0"){
            playerCount += 1;
        }
        player.currentOasisDeadline  =   block.timestamp + OasisDuration;
    
        player.currentTicket        =   keccak256(abi.encodePacked(msg.sender));
        player.currentKeyIndex      =   0;
        player.state                =   1;
        //player.currentTicket        =   2 * abi.encodePacked(msg.sender);
    
        return player.currentTicket;
    }
    

    
    function validateKey(
        bytes32 r,
        bytes32 s,
        uint8   v
    )
    external
    {
        //first we check the deadline has not passed
        //require(block.timestamp < players[msg.sender].currentOasisDeadline, "DEADLINE_PASSED");
        
        Key memory key  =   keys[players[msg.sender].currentKeyIndex];
        bytes32 hash    =   keccak256(abi.encodePacked(msg.sender, players[msg.sender].currentTicket));
        
        bytes32 ethHash = toEthSignedMessageHash(hash);
        
        require(ecrecover(ethHash, v, r, s) == key.publicKey, "Wrong signature");
    
        players[msg.sender].currentTicket = keccak256(abi.encodePacked(r, s, v));
        players[msg.sender].currentKeyIndex += 1;
        
        emit KeyFound(msg.sender, players[msg.sender].currentKeyIndex);
        
        if(players[msg.sender].currentKeyIndex == keyCounter)
        {
            startLottery();
        }
    }
    
    function startLottery()
    internal
    {
        if(!playerFinished[msg.sender]) {
            playerFinishedCount += 1;
            playerFinished[msg.sender] = true;
        }
        
        //Remove from whitelist (can play only once)
        whiteList[msg.sender] = false;
        
        uint rand = uint(keccak256(abi.encodePacked(players[msg.sender].currentTicket, block.timestamp)));
        players[msg.sender].earnedShells = maxReward * getWinning(rand) / 1000;
        
        uint shareLocked = players[msg.sender].earnedShells * shareLockedPercent / 100;
        uint shareTransfered = players[msg.sender].earnedShells - shareLocked;
        
        require(shellToken.transferFrom(shellHolder, msg.sender, shareTransfered));
        
        
        emit RewardClaimed(msg.sender, players[msg.sender].earnedShells);
        
        players[msg.sender].currentKeyIndex = 0;
        players[msg.sender].currentTicket = 0x0;
    }
    
    function viewkeyMessage(uint32 keyId)
    external view returns (string memory)
    {
    	return keys[keyId].message;
    }
    
    function viewEarnedShells()
    external view returns (uint256)
    {
        return players[msg.sender].earnedShells;
    }
    
    function getWinning(uint rand)
    internal view returns (uint256)
    {
        rand = rand % 1000;
        
        if(rand > 950){
            return 1000;
        }
        else if(rand > 900){
            return 500;
        }
        else if (rand > 800){
            return 250;
        }
        else if(rand > 500) {
            return 100;
        }
        else if(rand > 100) {
            return 50;
        }
        else{
            return 10;
        }
    }
    
    function getKeyData(uint32 id)
    external view returns(
        string memory message,
        address publicKey
        )
    {
        Key  memory key         = keys[id];
        message                 = key.message;
        publicKey               = key.publicKey;
    }
    
    function getCurrentTicket()
    external view returns (bytes32)
    {
        return players[msg.sender].currentTicket;
    }
    
    function getPlayerTicket(address player)
    external view returns (bytes32)
    {
        return players[player].currentTicket;
    }
    
    function getPlayerIndex(address player)
    external view returns (uint256)
    {
        return players[player].currentKeyIndex;
    }
    
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
    
    
    function addToWhiteList(address user)
    external
    {
        require(msg.sender == owner);
        whiteList[user] = true;
    }
    
    function removeFromWhiteList(address user)
    external
    {
        require(msg.sender == owner);
        whiteList[user] = false;
    }
    
    function transferOwnership(address newOwner) 
    public {
        require(msg.sender == owner);
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        owner = payable(newOwner);
    }
    
    function changeShellHolder(address _shellHolder) 
    public {
        require(msg.sender == owner);
        require(shellHolder != address(0), "New holder is the zero address");
        shellHolder = _shellHolder;
    }
    
    function changeMaxReward(uint _newReward) 
    public {
        require(msg.sender == owner);
        maxReward = _newReward;
    }
    
    function setWhitelistNeeded(bool _needed) 
    public {
        require(msg.sender == owner);
        whitelistNeeded = _needed;
    }
    
    function setOpen(bool _open) 
    public {
        require(msg.sender == owner);
        open = _open;
    }
    
    function resetPlayerFinishedCount() 
    public {
        require(msg.sender == owner);
        playerFinishedCount = 0;
    }

}

a solidity ^0.4.11;

import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";

contract ScriptCallable {
    address public determineWinnerScript;

    function ScriptCallable() public {
        determineWinnerScript = msg.sender;
    }

    modifier onlyScript() {
        assert(msg.sender == determineWinnerScript);
        _;
    }

    function transferOwnership(address newAddress) public onlyScript {
        if (newAddress != address(0)) {
            determineWinnerScript = newAddress;
        }
    }
}

contract RandomExample is usingOraclize, ScriptCallable
{
    uint public oraclizeGasCost;
    uint public oraclizeGasLimit;
    uint public oraclizeBytes;
    uint public oraclizeDelay;
    
    uint public totalJackpotEven;
    uint public totalJackpotOdd;
    
    uint public gameIndex;
    
    uint public numElementsEven;
    uint public numElementsOdd;

    uint public minimumBet = 0.01 ether;
    uint public commission = 33;
    uint public zoomraffleFee;
    
    mapping (address => uint256) public betsEven;
    mapping (address => uint256) public betsOdd;
    
    mapping (address => uint256) public wins;
    
    address[] public playersEven;
    address[] public playersOdd;

    event Win(address indexed winner, uint indexed gameIndex, uint value, uint jackpot);
    event Bet(address betAddress, uint indexed gameIndex, uint256 value);
    event ProofFailed(uint indexed gameIndex);


    function RandomExample() payable
    {
        oraclizeGasLimit = 250000;
        oraclizeGasCost = 10*10**9;
        oraclizeBytes = 32;
        oraclize_setCustomGasPrice(oraclizeGasCost);
        oraclize_setProof(proofType_Ledger); // sets the Ledger authenticity proof in the constructor
    }

    function () public payable
    {
        // Make the bet for the current game by default.
        placeBet(gameIndex);
    }
    
    function placeBet(uint _gameIndex) payable
    {
        if (gameIndex % 2 == 0)
        {
            placeBetEven(_gameIndex);
        }
        else
        {
            placeBetOdd(_gameIndex);
        }
    }

    function placeBetEven(uint _gameIndex) private
    {
        require(msg.value >= minimumBet);
        require(_gameIndex == gameIndex);
        if (numElementsOdd != 0) {
            cleanupOdd();
        }
        if (betsEven[msg.sender] == 0)
        {
            if(numElementsEven == playersEven.length) {
                playersEven.length += 1;
            }
            playersEven[numElementsEven++] = msg.sender;
        }
        betsEven[msg.sender] += msg.value;
        totalJackpotEven += msg.value;
        Bet(msg.sender, gameIndex, msg.value);
    }
    
    function placeBetOdd(uint _gameIndex) private
    {
        require(msg.value >= minimumBet);
        require(_gameIndex == gameIndex);
        if (numElementsEven != 0) {
            cleanupEven();
        }
        if (betsOdd[msg.sender] == 0)
        {
            if(numElementsOdd == playersOdd.length) {
                playersOdd.length += 1;
            }
            playersOdd[numElementsOdd++] = msg.sender;
        }
        betsOdd[msg.sender] += msg.value;
        totalJackpotOdd += msg.value;
        Bet(msg.sender, gameIndex, msg.value);
    }
    
    function determineWinner(string _result)
        onlyOraclize
        onlyTwoBetsAndMore
    {
        if (gameIndex % 2 == 0)
        {
            determineWinnerEven(_result);
        }
        else
        {
            determineWinnerOdd(_result);
        }
    }

    function determineWinnerEven(string _result) private
    {
        uint randomNumber = uint(sha3(_result)) % totalJackpotEven;
        address winner = 0;
        uint count = 0;
        for (uint i = 0; i < numElementsEven; i++)
        {
            address player = playersEven[i];
            count += betsEven[player];
            if (count >= randomNumber && winner == 0)
            {
                Win(player, gameIndex, betsEven[player], totalJackpotEven);
                winner = player;
            }
        }
        uint fee = totalJackpotEven / commission;
        zoomraffleFee += fee;
        totalJackpotEven = totalJackpotEven - (oraclizeGasLimit * oraclizeGasCost) - fee;
        wins[winner] += totalJackpotEven;
        gameIndex++;
    }
    
    function determineWinnerOdd(string _result) private
    {
        uint randomNumber = uint(sha3(_result)) % totalJackpotOdd;
        address winner = 0;
        uint count = 0;
        for (uint i = 0; i < numElementsOdd; i++)
        {
            address player = playersOdd[i];
            count += betsOdd[player];
            if (count >= randomNumber && winner == 0)
            {
                Win(player, gameIndex, betsOdd[player], totalJackpotOdd);
                winner = player;
            }
        }
        uint fee = totalJackpotOdd / commission;
        zoomraffleFee += fee;
        totalJackpotOdd = totalJackpotOdd - (oraclizeGasLimit * oraclizeGasCost) - fee;
        wins[winner] += totalJackpotOdd;
        gameIndex++;
    }

    function claimWinnings()
    {
        require(wins[msg.sender] != 0);
        msg.sender.transfer(wins[msg.sender]);
        wins[msg.sender] = 0;
    }
    
    function collectFees() onlyScript
    {
        determineWinnerScript.transfer(zoomraffleFee);
    }

    function getWinningsBalance(address player) constant returns (uint) {
        return wins[player];
    }

    function cleanupEven() private
    {
        for (uint i = 0; i < numElementsEven; i++)
        {
            address player = playersEven[i];
            delete betsEven[player];
        }
        delete numElementsEven;
        delete totalJackpotEven;
    }
    
    function cleanupOdd() private
    {
        for (uint i = 0; i < numElementsOdd; i++)
        {
            address player = playersOdd[i];
            delete betsOdd[player];
        }
        delete numElementsOdd;
        delete totalJackpotOdd;
    }

    function setMinimumBet(uint newMinBet) onlyScript
    {
        minimumBet = newMinBet;
    }

    function setOraclizeGasCost(uint newCost) onlyScript
    {
        oraclize_setCustomGasPrice(newCost);
    }

    function setCommission(uint newCommission) onlyScript
    {
        commission = newCommission;
    }

    function setOraclizeBytes(uint newBytes) onlyScript
    {
        oraclizeBytes = newBytes;
    }

    function setOraclizeDelay(uint newDelay) onlyScript
    {
        oraclizeDelay = newDelay;
    }

    function setOraclizeGasLimit(uint newGasLimit) onlyScript
    {
        oraclizeGasLimit = newGasLimit;
    }

    // the callback function is called by Oraclize when the result is ready
    // the oraclize_randomDS_proofVerify modifier prevents an invalid proof to execute this function code:
    // the proof validity is fully verified on-chain
    function __callback(bytes32 _queryId, string _result, bytes _proof) onlyOraclize
    {
        if (oraclize_randomDS_proofVerify__returnCode(_queryId, _result, _proof) != 0)
        {
            ProofFailed(gameIndex);
        }
        else
        {
            determineWinner(_result);
        }
    }

    modifier onlyTwoBetsAndMore() {
        uint numElements = (gameIndex % 2 == 0) ? numElementsEven : numElementsOdd;
        assert(numElements >= 2);
        _;
    }

    modifier onlyOraclize() {
        if (msg.sender != oraclize_cbAddress()) throw;
        _;
    }

    function update() onlyScript payable {
        // Oraclize fees are taken from jackpot.
        bytes32 queryId = oraclize_newRandomDSQuery(oraclizeDelay, oraclizeBytes, oraclizeGasLimit);
    }
}

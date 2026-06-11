// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract VoteWeighted {
    IERC20 public immutable usdc;
    address public owner;

    struct Poll {
        string question;
        string[] options;
        uint256[] tallies;
        uint256 deadline;
        bool finalized;
    }
    Poll[] public polls;
    mapping(uint256 => mapping(address => uint256)) public staked;

    event PollCreated(uint256 indexed id, string question, uint256 deadline);
    event Voted(uint256 indexed id, address voter, uint256 option, uint256 weight);
    event Finalized(uint256 indexed id, uint256 winningOption);

    constructor(address _usdc) {
        require(_usdc != address(0), "BAD_USDC");
        usdc = IERC20(_usdc);
        owner = msg.sender;
    }

    function createPoll(string calldata question, string[] calldata options, uint256 duration) external {
        require(options.length >= 2, "MIN_2_OPTIONS");
        Poll storage p = polls.push();
        p.question = question;
        p.deadline = block.timestamp + duration;
        for (uint256 i; i < options.length; i++) { p.options.push(options[i]); p.tallies.push(0); }
        emit PollCreated(polls.length - 1, question, p.deadline);
    }

    function vote(uint256 pollId, uint256 option, uint256 amount) external {
        Poll storage p = polls[pollId];
        require(block.timestamp < p.deadline && !p.finalized, "CLOSED");
        require(option < p.options.length, "BAD_OPTION");
        require(usdc.transferFrom(msg.sender, address(this), amount), "TRANSFER_FAILED");
        staked[pollId][msg.sender] += amount;
        p.tallies[option] += amount;
        emit Voted(pollId, msg.sender, option, amount);
    }

    function finalize(uint256 pollId) external {
        Poll storage p = polls[pollId];
        require(block.timestamp >= p.deadline && !p.finalized, "CANNOT");
        p.finalized = true;
        uint256 best; uint256 bestVal;
        for (uint256 i; i < p.tallies.length; i++) { if (p.tallies[i] > bestVal) { bestVal = p.tallies[i]; best = i; } }
        emit Finalized(pollId, best);
    }

    function refund(uint256 pollId) external {
        Poll storage p = polls[pollId];
        require(p.finalized, "NOT_FINALIZED");
        uint256 amt = staked[pollId][msg.sender];
        require(amt > 0, "NOTHING");
        staked[pollId][msg.sender] = 0;
        require(usdc.transfer(msg.sender, amt), "TRANSFER_FAILED");
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./IERC20.sol";

contract Vesting is Ownable {

	struct S_Vesting {
		uint id;
		address userAddress;
		address tokenAddress;
		uint totalTokens;
		uint claimedTokens;
		uint startDay;
		uint numberDays;
	}

	S_Vesting[] private vestingRequests;
	uint private nbRequests;

	address[] private whitelist;
	uint private nbWhitelist;

	event AddToWhitelist(address userAddress);
	event RemoveFromWhitelist(address userAddress);
	event NewVestingRequest(address userAddress, address tokenAddress, uint totalTokens, uint numberDays);
	event ClaimedVestedTokens(address userAddress, address tokenAddress, uint claimedTokens);

	modifier onlyWhitelist() {
		require(getWhitelistIndex(_msgSender()) != -1, "Address isn't whitelisted.");
		_;
	}

	function getVestingInformation(uint id) public view returns (S_Vesting memory) {
		return vestingRequests[id];
	}

	function getNbRequests() public view returns (uint) {
		return nbRequests;
	}

	function getWhitelist() public view returns (address[] memory) {
		return whitelist;
	}

	function getWhitelistIndex(address userAddress) private view returns (int) {
		for (uint i = 0; i < getNbWhitelist(); i++) {
			if (userAddress == whitelist[i]) {
				return int(i);
			}
		}
		return -1;
	}

	function getNbWhitelist() private view returns (uint) {
		return nbWhitelist;
	}

	function getClaimableAmount(uint id) private view returns (uint) {
		uint elapsedDays = block.timestamp / 86400 - vestingRequests[id].startDay;
		if (elapsedDays >= vestingRequests[id].numberDays)
			return vestingRequests[id].totalTokens - vestingRequests[id].claimedTokens;
		else
			return (vestingRequests[id].totalTokens / vestingRequests[id].numberDays * elapsedDays) - vestingRequests[id].claimedTokens;
	}

	function addToWhitelist(address userAddress) external onlyOwner {
		require(getWhitelistIndex(userAddress) == -1, "Address is already whitelisted.");
		whitelist.push(userAddress);
		nbWhitelist++;
		emit AddToWhitelist(userAddress);
	}

	function removeFromWhitelist(address userAddress) external onlyOwner {
		int index = getWhitelistIndex(userAddress);
		if (index != -1) {
			whitelist[uint(index)] = whitelist[getNbWhitelist() - 1];
			whitelist.pop();
			nbWhitelist--;
			emit RemoveFromWhitelist(userAddress);
		}
	}

	function vestTokens(address tokenAddress, uint totalTokens, uint numberDays) external onlyWhitelist {
		require(numberDays > 0, "Unable to vest for less than 1 day.");
		require(totalTokens > 0, "Unable to vest 0 tokens.");
		S_Vesting memory newVestingRequest = S_Vesting(getNbRequests(), _msgSender(), tokenAddress, totalTokens, 0, block.timestamp / 86400, numberDays);
		IERC20 userToken = IERC20(tokenAddress);
		userToken.transferFrom(_msgSender(), address(this), totalTokens);
		vestingRequests.push(newVestingRequest);
		nbRequests++;
		emit NewVestingRequest(_msgSender(), tokenAddress, totalTokens, numberDays);
	}

	function claimVestedTokens(uint id) external onlyWhitelist {
		require(id <= getNbRequests() && id >= 0, "Invalid ID.");
		require(_msgSender() == vestingRequests[id].userAddress, "You can't claim tokens you didn't deposit.");
		require(vestingRequests[id].claimedTokens != vestingRequests[id].totalTokens, "All tokens have already been claimed.");
		IERC20 userToken = IERC20(vestingRequests[id].tokenAddress);
		uint claimableTokens = getClaimableAmount(id);
		require(claimableTokens > vestingRequests[id].claimedTokens, "You have already claimed all your available tokens yet.");
		userToken.transfer(_msgSender(), claimableTokens);
		vestingRequests[id].claimedTokens += claimableTokens;
		emit ClaimedVestedTokens(vestingRequests[id].userAddress, vestingRequests[id].tokenAddress, claimableTokens);
	}
}
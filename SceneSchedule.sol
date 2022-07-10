// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

contract FeeCache {
    uint256 private feeWeiPerSecond;
    uint256 private feeWeiPerMinute;
    uint256 private feeWeiPerHour;
    uint256 private feeWeiPerDay;

    constructor() {
        setFee(1);
    }

    function setFee(uint256 newFeeWeiPerSecond) public {
        feeWeiPerSecond = newFeeWeiPerSecond;
        feeWeiPerMinute = 60 * feeWeiPerSecond;
        feeWeiPerHour = 60 * feeWeiPerMinute;
        feeWeiPerDay = 24 * feeWeiPerHour;
    }

    function getFeePerSecond() public view returns (uint256 weiPerSecond) {
        return feeWeiPerSecond;
    }

    function getFeePerMinute() public view returns (uint256 weiPerMinute) {
        return feeWeiPerMinute;
    }

    function getFeePerHour() public view returns (uint256 weiPerHour) {
        return feeWeiPerHour;
    }

    function getFeePerDay() public view returns (uint256 weiPerDay) {
        return feeWeiPerDay;
    }
}

contract SceneSchedule is Ownable {
    FeeCache private fee;

    constructor() {
        fee = new FeeCache();
    }

    function setFee(uint256 newFeeWeiPerSecond) public {
        fee.setFee(newFeeWeiPerSecond);
    }

    function getFeePerSecond() public view returns (uint256 weiPerSecond) {
        return fee.getFeePerSecond();
    }

    function getFeePerMinute() public view returns (uint256 weiPerMinute) {
        return fee.getFeePerMinute();
    }

    function getFeePerHour() public view returns (uint256 weiPerHour) {
        return fee.getFeePerHour();
    }
    
    function getFeePerDay() public view returns (uint256 weiPerDay) {
        return fee.getFeePerDay();
    }

    
}
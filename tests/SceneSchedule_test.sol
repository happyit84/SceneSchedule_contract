// SPDX-License-Identifier: GPL-3.0
        
pragma solidity >=0.4.22 <0.9.0;

// This import is automatically injected by Remix
import "remix_tests.sol"; 

// This import is required to use custom transaction context
// Although it may fail compilation in 'Solidity Compiler' plugin
// But it will work fine in 'Solidity Unit Testing' plugin
import "remix_accounts.sol";
import "../SceneSchedule.sol";

// File name has to end with '_test.sol', this file can contain more than one testSuite contracts
contract TestSceneSchedule is SceneSchedule {

    uint createdScheduleIndex;
    ScheduleInfo scheduleInfo;

    /// 'beforeAll' runs before all other tests
    /// More special functions are: 'beforeEach', 'beforeAll', 'afterEach' & 'afterAll'
    function beforeAll() public {        
        // <instantiate contract>
        Assert.equal(uint(1), uint(1), "1 should be equal to 1");
        //sceneSchedule = new SceneSchedule();
        createdScheduleIndex = NotReserved;
    }

    function beforeEach() public {

    }

    function afterAll() public {

    }

    function afterEach() public {

    }

    function testFeeCache() public {
        //FeeCache fee = new FeeCache();
        Assert.equal(getFeePerSecond(), uint256(1), "Initial Fee per second should be 1 wei.");
        setFee(10);
        Assert.equal(getFeePerSecond(), uint256(10), "Fee per second should be 10 wei.");
        Assert.equal(getFeePerMinute(), uint256(600), "Fee per minute should be 600 wei.");
        Assert.equal(getFeePerHour(), uint256(36000), "Fee per hour should be 36000 wei.");
        Assert.equal(getFeePerDay(), uint256(864000), "Fee per day should be 864000 wei.");
        setFee(1);
        Assert.equal(getFeePerSecond(), uint256(1), "Fee per second should be 10 wei.");
        Assert.equal(getFeePerMinute(), uint256(60), "Fee per minute should be 600 wei.");
        Assert.equal(getFeePerHour(), uint256(3600), "Fee per hour should be 36000 wei.");
        Assert.equal(getFeePerDay(), uint256(86400), "Fee per day should be 864000 wei.");
    }

    function checkSuccess() public {
        // Use 'Assert' methods: https://remix-ide.readthedocs.io/en/latest/assert_library.html
        Assert.ok(2 == 2, 'should be true');
        Assert.greaterThan(uint(2), uint(1), "2 should be greater than to 1");
        Assert.lesserThan(uint(2), uint(3), "2 should be lesser than to 3");
    }

    function checkSuccess2() public pure returns (bool) {
        // Use the return value (true or false) to test the contract
        return true;
    }
    
    function checkFailure() public {
        Assert.notEqual(uint(1), uint(2), "1 should not be equal to 2");
    }

    /// Custom Transaction Context: https://remix-ide.readthedocs.io/en/latest/unittesting.html#customization
    /// #sender: account-0
    /// #value: 3600
    function checkSenderAndValue_createSchedule() public payable {
        // account index varies 0-9, value is in wei
        Assert.equal(msg.sender, TestsAccounts.getAccount(0), "Invalid sender");
        Assert.equal(msg.value, 3600, "Invalid value");

        // create schedule
        uint timestampNow = block.timestamp;
        uint remainder = timestampNow % 3600;
        uint earliestStartTime = timestampNow - remainder + 3600;
        //uint earliestEndTime = earliestStartTime + 3600;
        uint earliestEndTime = 0;
        //string memory data = "{msg:'test'}";
        string memory data = "...";
        (uint256 scheduleIndex, ScheduleInfo info) = createSchedule(earliestStartTime, earliestEndTime, data);
        scheduleInfo = info;
        Assert.ok(scheduleIndex != NotReserved, "scheduleIndex != NotReserved");
    }

    function shouldFail_createScheduleOnReservedTime() public payable {
        // expected to fail when trying to create schedule on the time slot already reserved.
        string memory data = "...";
        createSchedule(scheduleInfo.startTimestamp(), scheduleInfo.endTimestamp(), data);
    }
}
    
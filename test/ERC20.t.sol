// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// ──────────────────────────────────────────────────────────────────────────────
// 구현해야 할 인터페이스 (EIP-20 표준)
// 파일 경로: src/MyERC20.sol
// 컨트랙트 이름: MyERC20
// ──────────────────────────────────────────────────────────────────────────────
interface IERC20 {
    // ── Events ──────────────────────────────────────────────────────────────
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ── Metadata ─────────────────────────────────────────────────────────────
    function name()        external view returns (string memory);
    function symbol()      external view returns (string memory);
    function decimals()    external view returns (uint8);

    // ── State ────────────────────────────────────────────────────────────────
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);

    // ── Core ─────────────────────────────────────────────────────────────────
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IMyERC20 is IERC20 {
    // 생성자 시그니처 확인용 (직접 호출하지 않고 배포 시 사용)
    // constructor(string name, string symbol, uint8 decimals, uint256 initialSupply)
}

contract ERC20Test is Test {
    // ── 배포 정보 ─────────────────────────────────────────────────────────────
    string constant ARTIFACT = "MyERC20.sol:MyERC20";

    string  constant TOKEN_NAME     = "MyToken";
    string  constant TOKEN_SYMBOL   = "MTK";
    uint8   constant TOKEN_DECIMALS = 18;
    uint256 constant INITIAL_SUPPLY = 1_000_000 * 1e18;

    // ── 테스트 계정 ───────────────────────────────────────────────────────────
    address owner   = makeAddr("owner");
    address alice   = makeAddr("alice");
    address bob     = makeAddr("bob");
    address charlie = makeAddr("charlie");

    IERC20 token;

    // =========================================================================
    // setUp: 각 테스트 함수 실행 전 호출됨
    // =========================================================================
    function setUp() public {
        vm.startPrank(owner);
        bytes memory args = abi.encode(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS, INITIAL_SUPPLY);
        address deployed  = deployCode(ARTIFACT, args);
        token = IERC20(deployed);
        vm.stopPrank();
    }

    // =========================================================================
    // 1. Metadata
    // =========================================================================
    function test_metadata_name() public view {
        assertEq(token.name(), TOKEN_NAME, "name() mismatch");
    }

    function test_metadata_symbol() public view {
        assertEq(token.symbol(), TOKEN_SYMBOL, "symbol() mismatch");
    }

    function test_metadata_decimals() public view {
        assertEq(token.decimals(), TOKEN_DECIMALS, "decimals() mismatch");
    }

    // =========================================================================
    // 2. Initial State
    // =========================================================================
    function test_initialSupply_totalSupply() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY, "totalSupply != INITIAL_SUPPLY");
    }

    function test_initialSupply_ownerBalance() public view {
        assertEq(
            token.balanceOf(owner),
            INITIAL_SUPPLY,
            "owner balance != INITIAL_SUPPLY after deploy"
        );
    }

    function test_initialBalance_strangerIsZero() public view {
        assertEq(token.balanceOf(alice), 0, "alice initial balance should be 0");
    }

    // =========================================================================
    // 3. transfer()
    // =========================================================================
    function test_transfer_basic() public {
        uint256 amount = 100 * 1e18;

        vm.prank(owner);
        bool ok = token.transfer(alice, amount);

        assertTrue(ok, "transfer should return true");
        assertEq(token.balanceOf(alice), amount, "alice balance mismatch after transfer");
        assertEq(
            token.balanceOf(owner),
            INITIAL_SUPPLY - amount,
            "owner balance mismatch after transfer"
        );
    }

    function test_transfer_emitsTransferEvent() public {
        uint256 amount = 50 * 1e18;

        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Transfer(owner, alice, amount);

        vm.prank(owner);
        token.transfer(alice, amount);
    }

    function test_transfer_toZeroAddress_reverts() public {
        vm.prank(owner);
        vm.expectRevert();
        token.transfer(address(0), 1);
    }

    function test_transfer_exceedsBalance_reverts() public {
        uint256 amount = token.balanceOf(alice) + 1;
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, amount);
    }

    function test_transfer_zeroAmount_succeeds() public {
        vm.prank(owner);
        bool ok = token.transfer(alice, 0);
        assertTrue(ok, "zero-amount transfer should succeed");
    }

    function test_transfer_selfTransfer() public {
        uint256 before = token.balanceOf(owner);
        vm.prank(owner);
        token.transfer(owner, before);
        assertEq(token.balanceOf(owner), before, "self-transfer should preserve balance");
    }

    // Fuzz: 임의 금액 이전이 잔액을 보존하는지 확인
    function testFuzz_transfer_balanceConservation(uint256 amount) public {
        amount = bound(amount, 0, INITIAL_SUPPLY);

        uint256 ownerBefore = token.balanceOf(owner);
        uint256 aliceBefore = token.balanceOf(alice);

        vm.prank(owner);
        token.transfer(alice, amount);

        assertEq(token.balanceOf(owner), ownerBefore - amount);
        assertEq(token.balanceOf(alice), aliceBefore + amount);
    }

    // =========================================================================
    // 4. approve() & allowance()
    // =========================================================================
    function test_approve_basic() public {
        uint256 amount = 200 * 1e18;

        vm.prank(owner);
        bool ok = token.approve(alice, amount);

        assertTrue(ok, "approve should return true");
        assertEq(token.allowance(owner, alice), amount, "allowance mismatch");
    }

    function test_approve_emitsApprovalEvent() public {
        uint256 amount = 300 * 1e18;

        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Approval(owner, alice, amount);

        vm.prank(owner);
        token.approve(alice, amount);
    }

    function test_approve_overwrite() public {
        vm.startPrank(owner);
        token.approve(alice, 100 * 1e18);
        token.approve(alice, 50 * 1e18);
        vm.stopPrank();

        assertEq(token.allowance(owner, alice), 50 * 1e18, "allowance should be overwritten");
    }

    function test_approve_toZeroAddress_reverts() public {
        vm.prank(owner);
        vm.expectRevert();
        token.approve(address(0), 1);
    }

    function test_allowance_defaultIsZero() public view {
        assertEq(token.allowance(alice, bob), 0, "default allowance should be 0");
    }

    // =========================================================================
    // 5. transferFrom()
    // =========================================================================
    function test_transferFrom_basic() public {
        uint256 amount = 100 * 1e18;

        // owner → alice에게 사용 권한 부여
        vm.prank(owner);
        token.approve(alice, amount);

        // alice가 owner의 토큰을 bob에게 전송
        vm.prank(alice);
        bool ok = token.transferFrom(owner, bob, amount);

        assertTrue(ok, "transferFrom should return true");
        assertEq(token.balanceOf(bob), amount, "bob balance mismatch");
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount, "owner balance mismatch");
    }

    function test_transferFrom_decreasesAllowance() public {
        uint256 approved = 200 * 1e18;
        uint256 spent    = 60 * 1e18;

        vm.prank(owner);
        token.approve(alice, approved);

        vm.prank(alice);
        token.transferFrom(owner, bob, spent);

        assertEq(
            token.allowance(owner, alice),
            approved - spent,
            "allowance should decrease by spent amount"
        );
    }

    function test_transferFrom_emitsTransferEvent() public {
        uint256 amount = 10 * 1e18;

        vm.prank(owner);
        token.approve(alice, amount);

        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Transfer(owner, bob, amount);

        vm.prank(alice);
        token.transferFrom(owner, bob, amount);
    }

    function test_transferFrom_exceedsAllowance_reverts() public {
        uint256 approved = 50 * 1e18;

        vm.prank(owner);
        token.approve(alice, approved);

        vm.prank(alice);
        vm.expectRevert();
        token.transferFrom(owner, bob, approved + 1);
    }

    function test_transferFrom_noAllowance_reverts() public {
        vm.prank(alice);
        vm.expectRevert();
        token.transferFrom(owner, bob, 1);
    }

    function test_transferFrom_exceedsBalance_reverts() public {
        // alice는 잔액이 0이지만 bob에게 많은 allowance를 줌
        uint256 bigAmount = INITIAL_SUPPLY;

        vm.prank(alice);
        token.approve(bob, bigAmount);

        vm.prank(bob);
        vm.expectRevert();
        token.transferFrom(alice, charlie, bigAmount);
    }

    function test_transferFrom_toZeroAddress_reverts() public {
        vm.prank(owner);
        token.approve(alice, 100);

        vm.prank(alice);
        vm.expectRevert();
        token.transferFrom(owner, address(0), 100);
    }

    // =========================================================================
    // 6. totalSupply 불변 검증
    // =========================================================================
    function test_totalSupply_unchangedAfterTransfer() public {
        vm.prank(owner);
        token.transfer(alice, 100 * 1e18);

        assertEq(token.totalSupply(), INITIAL_SUPPLY, "totalSupply must not change on transfer");
    }

    function test_totalSupply_unchangedAfterTransferFrom() public {
        vm.prank(owner);
        token.approve(alice, 100 * 1e18);

        vm.prank(alice);
        token.transferFrom(owner, bob, 50 * 1e18);

        assertEq(token.totalSupply(), INITIAL_SUPPLY, "totalSupply must not change on transferFrom");
    }

    // =========================================================================
    // 7. 복합 시나리오
    // =========================================================================
    function test_scenario_multiHopTransfer() public {
        // owner → alice → bob → charlie
        uint256 step = 100 * 1e18;

        vm.prank(owner);
        token.transfer(alice, step);

        vm.prank(alice);
        token.transfer(bob, step);

        vm.prank(bob);
        token.transfer(charlie, step);

        assertEq(token.balanceOf(charlie), step);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 0);
    }

    function test_scenario_delegateSpend() public {
        // alice가 bob과 charlie 모두에게 allowance 부여
        uint256 totalDeposit = 500 * 1e18;

        vm.prank(owner);
        token.transfer(alice, totalDeposit);

        vm.startPrank(alice);
        token.approve(bob,     300 * 1e18);
        token.approve(charlie, 200 * 1e18);
        vm.stopPrank();

        vm.prank(bob);
        token.transferFrom(alice, bob, 300 * 1e18);

        vm.prank(charlie);
        token.transferFrom(alice, charlie, 200 * 1e18);

        assertEq(token.balanceOf(alice),   0,           "alice should be drained");
        assertEq(token.balanceOf(bob),     300 * 1e18,  "bob balance mismatch");
        assertEq(token.balanceOf(charlie), 200 * 1e18,  "charlie balance mismatch");
        assertEq(token.allowance(alice, bob),     0,    "bob allowance should be 0");
        assertEq(token.allowance(alice, charlie), 0,    "charlie allowance should be 0");
    }

    // =========================================================================
    // 8. Invariant 스냅샷: 전체 잔액 합 == totalSupply
    // =========================================================================
    function test_invariant_sumOfBalances() public {
        // 여러 계정에 분산 후 합산
        address[] memory accounts = new address[](5);
        accounts[0] = owner;
        accounts[1] = alice;
        accounts[2] = bob;
        accounts[3] = charlie;
        accounts[4] = makeAddr("dave");

        vm.startPrank(owner);
        token.transfer(alice,   100 * 1e18);
        token.transfer(bob,     200 * 1e18);
        token.transfer(charlie, 300 * 1e18);
        token.transfer(accounts[4], 400 * 1e18);
        vm.stopPrank();

        uint256 sum;
        for (uint256 i; i < accounts.length; i++) {
            sum += token.balanceOf(accounts[i]);
        }

        assertEq(sum, token.totalSupply(), "sum of balances must equal totalSupply");
    }
}

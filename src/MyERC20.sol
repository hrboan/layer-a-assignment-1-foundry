// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ──────────────────────────────────────────────────────────────────────────────
// MyERC20 — ERC-20 직접 구현
// ──────────────────────────────────────────────────────────────────────────────

contract MyERC20 { //MyERC20이라는 스마트컨트랙트 선언

    string public name = "MyToken";
    string public symbol = "MTK";
    uint8 public decimals = 18; //토큰 소수점 자리수, 이더리움 토큰은 대부분 18 사용

    uint256 public totalSupply; //전체 발행량 저장 변수

    mapping(address => uint256) private _balances; //각 주소가 가진 토큰 개수 저장소
    mapping(address => mapping(address => uint256)) private _allowances; //누가 누구 대신 얼마 쓸 수 있는지

    event Transfer(address indexed from, address indexed to, uint256 value); //전송 로그, Transfer 이벤트
    event Approval(address indexed owner, address indexed spender, uint256 value); //승인 로그, Approval 이벤트


    constructor() { //컨트랙트가 배포될 때 딱 한 번 실행되는 함수, 초기 설정용
        totalSupply = 1000 * 10 ** decimals; //총 발행량 설정, decimals = 18이므로 소수점 곱하기, 1000 토큰이라는 뜻
        _balances[msg.sender] = totalSupply; //msg.sender = 컨트랙트를 배포한 사람 주소, 배포자가 모든 토큰을 처음에 다 가져감
    }


    function balanceOf(address account) public view returns (uint256) { //특정 주소가 가진 토큰 개수 조회
        return _balances[account]; //balances mapping에서 값 가져오기
    }

    function transfer(address to, uint256 amount) public returns (bool) { //토큰 보내는 함수
        require(_balances[msg.sender] >= amount, "not enough balance"); //돈 부족하면 실행 중단

        _balances[msg.sender] -= amount;
        _balances[to] += amount;

        emit Transfer(msg.sender, to, amount); //블록체인 로그 기록, 지갑/거래소가 이걸 보고 업데이트
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) { //다른 사람이 내 토큰을 대신 쓸 수 있도록 허락
        _allowances[msg.sender][spender] = amount; //msg.sender=나, spender=받는 사람

        emit Approval(msg.sender, spender, amount); // <-이벤트 발생, 로그 기록
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) { //얼마나 허용했는지 조회
        return _allowances[owner][spender]; //실행하면 허용한 토큰량 반환
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) { //승인 받은 사람이 대신 토큰을 보내는 함수
        require(_balances[from] >= amount, "not enough balance"); //잔액 체크, 실제 토큰이 있는지 확인
        require(_allowances[from][msg.sender] >= amount, "not allowed"); //승인 체크, 승인 받은 양 확인

        _balances[from] -= amount;
        _balances[to] += amount;
        _allowances[from][msg.sender] -= amount; //사용한 만큼 승인량 감소

        emit Transfer(from, to, amount); //이벤트 발생, 블록체인 로그 기록
        return true;
    }

}

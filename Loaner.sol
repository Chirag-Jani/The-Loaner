// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// store previous loans
// add tokens
// nft as a colatteral

contract Loaner {
    receive() external payable {}

    // owner
    address payable owner;

    // setting owner
    constructor() payable {
        owner = payable(msg.sender);
        payable(address(this)).transfer(10 ether);
        emit ContractDeployed(owner, address(this));
    }

    // User struct
    struct User {
        address payable userAddress;
        uint256 userReputation;
    }

    // Loan struct
    struct Loan {
        uint256 amount;
        uint256 remainingAmount;
        uint256 totalInstallments;
        uint256 remainingInstallments;
        uint256 lastPayment;
        uint256 lastAmount;
        uint256 nextPayment;
        uint256 nextAmount;
        uint256 penelty;
        uint256 interest;
        uint256 timeBetweenInstallments;
    }

    // to get loan details from address
    mapping(address => Loan) getLoan;

    // to get user details from address
    mapping(address => User) getUser;

    // to check the loan status
    mapping(address => bool) loanActive;

    // to check the max limit
    function checkCredibility(uint256 _interestRate, uint256 _installments)
        internal
        returns (uint256)
    {
        // getting reputation of a user
        uint256 repu = getUser[msg.sender].userReputation;

        // calculating
        uint256 credibleAmount = (repu * _interestRate) / _installments;

        // emitting event for the frontend
        emit CredibilityCheck(getUser[msg.sender], credibleAmount);

        // returning
        return credibleAmount;
    }

    // to check penelty
    function checkPenelty(
        uint256 _totalInstallments,
        uint256 _amount,
        uint256 _interestRate
    ) internal pure returns (uint256) {
        // calculating
        uint256 penelty = (_totalInstallments / (_amount * _interestRate));

        // returning
        return penelty;
    }

    // to take the loan
    function takeLoan(
        uint256 _amount,
        uint256 _totalInstallments,
        uint256 _interestRate,
        uint256 _timeBetweenInstallments
    ) public payable {
        require(_amount >= 3, "Minimum loan amount is 3 ether");

        // getting the user
        User storage user = getUser[msg.sender];

        // checking credibility
        if (user.userReputation != 0 && _amount > 3 ether) {
            uint256 cred = checkCredibility(_interestRate, _totalInstallments);
            require(cred >= _amount, "Max. credibility exceeds");
        } else {
            require(_amount <= 3 ether, "Not credible for more than 3 ethers");
        }

        // calculating penelty
        uint256 peneltyAmount = checkPenelty(
            _totalInstallments,
            _amount,
            _interestRate
        );

        // setting penelty to 0.3 if it's zero
        if (peneltyAmount == 0) {
            peneltyAmount = 0.3 ether;
        }

        uint256 iToPay = _amount / _totalInstallments;

        // setting first installment to 1 if it's zero
        if (iToPay == 0) {
            iToPay = 1 ether;
        }

        uint256 remainingAmount = _amount - iToPay;

        uint256 remainngInstallments = _totalInstallments - 1;

        uint256 nextToPay = iToPay + ((_interestRate * remainingAmount) / 100);

        // setting next installment to 1 if it's zero
        if (nextToPay == 0) {
            nextToPay = 1 ether;
        }

        // generating loan
        Loan memory loan = Loan(
            _amount,
            remainingAmount,
            _totalInstallments,
            remainngInstallments,
            block.timestamp,
            iToPay,
            block.timestamp + _timeBetweenInstallments,
            nextToPay,
            peneltyAmount,
            _interestRate,
            _timeBetweenInstallments
        );

        getLoan[msg.sender] = loan;

        loanActive[msg.sender] = true;

        // transfer money into user's account (amount - 1st installment)
        uint256 toTransfer = (_amount - iToPay) * 10**18;
        payable(msg.sender).transfer(toTransfer);

        emit LoanDetails(
            msg.sender,
            _amount,
            remainingAmount,
            _interestRate,
            peneltyAmount,
            nextToPay
        );
    }

    function payInstallment() public payable {
        // loan needs to be active
        require(loanActive[msg.sender], "You have repayed the loan");

        // get loan
        Loan storage loan = getLoan[msg.sender];

        // get installment
        uint256 installment = loan.nextAmount;

        // if penelty (add it here)
        if (loan.nextPayment < block.timestamp) {
            installment += loan.penelty;
        }

        // if this was the last installment set false (todo)

        if (loan.remainingInstallments - 1 >= 0) {
            // update remaining amount and installments
            loan.remainingAmount -= loan.nextAmount;
            loan.remainingInstallments -= 1;
            loan.lastPayment = block.timestamp;
            loan.lastAmount = installment;
            loan.nextPayment = block.timestamp + loan.timeBetweenInstallments;

            uint256 iToPay = loan.amount / loan.totalInstallments;

            // setting next installment to remaining if it's zero
            if (iToPay == 0) {
                iToPay = loan.remainingAmount;
            }

            loan.nextAmount =
                iToPay +
                ((loan.interest * loan.remainingAmount) / 100);

            // pay installment
            (bool sent, ) = msg.sender.call{value: installment}("");
            require(sent, "Fund Transfer Error");
        } else {
            loanActive[msg.sender] = false;
        }

        emit LoanDetails(
            msg.sender,
            loan.amount,
            loan.remainingAmount,
            loan.interest,
            loan.interest,
            loan.nextAmount
        );
    }

    function getLoanInfo()
        public
        view
        returns (
            uint256 amount,
            uint256 remainingAmount,
            uint256 remainngInstallments,
            uint256 nextPayment,
            uint256 interest
        )
    {
        Loan memory l = getLoan[msg.sender];
        return (
            l.amount,
            l.remainingAmount,
            l.remainingInstallments,
            l.nextAmount,
            l.interest
        );
    }

    event ContractDeployed(
        address indexed ownerAddress,
        address indexed contractAddress
    );
    event CredibilityCheck(User indexed user, uint256 indexed credibleAmount);
    event LoanDetails(
        address user,
        uint256 loanAmount,
        uint256 remainingAmount,
        uint256 interestRate,
        uint256 peneltyAmount,
        uint256 nextInstallment
    );
}

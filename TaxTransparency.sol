// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract TaxTransparency {
    enum Role { WP, AR, VERIFIER, KPP_HEAD, BANK, AUDITOR }
    enum PaymentStatus { PENDING, POSTED, ALLOCATED, RESTITUTED }
    enum RestitutionStatus { PENDING, APPROVED, REJECTED, DISBURSED }
    
    struct Payment {
        uint256 paymentId;
        string npwp;
        string taxType;
        uint256 amount;
        uint256 timestamp;
        address wpAddress;
        string documentHash;
        string allocationCode;
        PaymentStatus status;
    }
    
    struct RestitutionRequest {
        uint256 requestId;
        uint256 paymentId;
        uint256 amount;
        address requester;
        uint256 requestDate;
        mapping(uint8 => bool) approvals;
        uint8 approvalCount;
        RestitutionStatus status;
    }
    
    mapping(uint256 => Payment) public payments;
    mapping(uint256 => RestitutionRequest) public restitutions;
    mapping(address => Role) public userRole;
    mapping(string => uint256) public npwpToPaymentCount;
    
    uint256 public paymentCounter;
    uint256 public restitutionCounter;
    
    event PaymentRecorded(
        uint256 indexed paymentId,
        address indexed wpAddress,
        string npwp,
        uint256 amount,
        string allocationCode
    );
    
    event RestitutionRequested(
        uint256 indexed requestId,
        uint256 indexed paymentId,
        uint256 amount
    );
    
    event RestitutionApproved(
        uint256 indexed requestId,
        uint8 approvalCount
    );
    
    modifier onlyVerifiedWP() {
        require(userRole[msg.sender] == Role.WP, "Not verified WP");
        _;
    }
    
    modifier onlyAuthorizedVerifier() {
        require(
            userRole[msg.sender] == Role.AR || 
            userRole[msg.sender] == Role.VERIFIER ||
            userRole[msg.sender] == Role.KPP_HEAD,
            "Not authorized"
        );
        _;
    }
    
    function recordPayment(
        string memory _npwp,
        string memory _taxType,
        uint256 _amount,
        string memory _documentHash,
        string memory _allocationCode
    ) public onlyVerifiedWP returns (uint256) {
        paymentCounter++;
        
        payments[paymentCounter] = Payment({
            paymentId: paymentCounter,
            npwp: _npwp,
            taxType: _taxType,
            amount: _amount,
            timestamp: block.timestamp,
            wpAddress: msg.sender,
            documentHash: _documentHash,
            allocationCode: _allocationCode,
            status: PaymentStatus.POSTED
        });
        
        npwpToPaymentCount[_npwp]++;
        
        emit PaymentRecorded(
            paymentCounter,
            msg.sender,
            _npwp,
            _amount,
            _allocationCode
        );
        
        return paymentCounter;
    }
    
    function requestRestitution(
        uint256 _paymentId,
        uint256 _amount,
        string memory _reason
    ) public onlyVerifiedWP returns (uint256) {
        require(_paymentId <= paymentCounter, "Payment not found");
        require(_amount <= payments[_paymentId].amount, "Amount exceeds payment");
        require(payments[_paymentId].wpAddress == msg.sender, "Not owner");
        
        restitutionCounter++;
        
        restitutions[restitutionCounter].requestId = restitutionCounter;
        restitutions[restitutionCounter].paymentId = _paymentId;
        restitutions[restitutionCounter].amount = _amount;
        restitutions[restitutionCounter].requester = msg.sender;
        restitutions[restitutionCounter].requestDate = block.timestamp;
        restitutions[restitutionCounter].status = RestitutionStatus.PENDING;
        
        emit RestitutionRequested(
            restitutionCounter,
            _paymentId,
            _amount
        );
        
        return restitutionCounter;
    }
    
    function approveRestitution(
        uint256 _requestId,
        uint8 _approvalIndex
    ) public onlyAuthorizedVerifier returns (bool) {
        require(_requestId <= restitutionCounter, "Request not found");
        require(_approvalIndex < 3, "Invalid approval index");
        require(
            restitutions[_requestId].status == RestitutionStatus.PENDING,
            "Request not pending"
        );
        
        RestitutionRequest storage request = restitutions[_requestId];
        
        require(!request.approvals[_approvalIndex], "Already approved");
        
        request.approvals[_approvalIndex] = true;
        request.approvalCount++;
        
        if (request.approvalCount >= 2) {
            request.status = RestitutionStatus.APPROVED;
            emit RestitutionApproved(_requestId, request.approvalCount);
        }
        
        return true;
    }
    
    function verifyPayment(uint256 _paymentId)
        public
        view
        returns (
            string memory npwp,
            string memory taxType,
            uint256 amount,
            string memory status,
            string memory allocationCode,
            uint256 timestamp
        )
    {
        require(_paymentId <= paymentCounter, "Payment not found");
        
        Payment memory payment = payments[_paymentId];
        
        return (
            payment.npwp,
            payment.taxType,
            payment.amount,
            paymentStatusToString(payment.status),
            payment.allocationCode,
            payment.timestamp
        );
    }
    
    function paymentStatusToString(PaymentStatus status)
        internal
        pure
        returns (string memory)
    {
        if (status == PaymentStatus.PENDING) return "PENDING";
        if (status == PaymentStatus.POSTED) return "POSTED";
        if (status == PaymentStatus.ALLOCATED) return "ALLOCATED";
        if (status == PaymentStatus.RESTITUTED) return "RESTITUTED";
        return "UNKNOWN";
    }
}
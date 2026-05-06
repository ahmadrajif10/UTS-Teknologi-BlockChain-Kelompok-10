// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract TaxTransparency {
    // Definisi peran pengguna untuk kontrol akses berbasis RBAC
    enum Role { WP, AR, VERIFIER, KPP_HEAD, BANK }
    // Status siklus hidup transaksi pembayaran dan restitusi
    enum Status { PENDING, POSTED, APPROVED, REJECTED }

    // Struktur data untuk mencatat pembayaran pajak
    struct Payment { uint256 id; string npwp; uint256 amount; string allocCode; address owner; Status status; }
    // Struktur data untuk mencatat permohonan restitusi dengan tracking approval
    struct Request { uint256 id; uint256 payId; uint256 amount; uint8 approvals; Status status; }

    // Mapping penyimpanan data utama: ID → Payment/Request, Address → Role
    mapping(uint256 => Payment) public payments;
    mapping(uint256 => Request) public requests;
    mapping(address => Role) public roles;
    // Counter untuk menghasilkan ID unik secara otomatis (auto-increment)
    uint256 public payCount; uint256 public reqCount;

    // Event untuk logging transparan yang dapat di-index oleh front-end dan explorer
    event PaymentLogged(uint256 id, address wp, uint256 amt);
    event RestitutionApproved(uint256 reqId);

    // Modifier: Membatasi akses fungsi hanya untuk pengguna dengan role WP
    modifier onlyWP() { require(roles[msg.sender] == Role.WP); _; }
    // Modifier: Membatasi akses fungsi hanya untuk verifier (AR/Verifikator/Kepala KPP)
    modifier onlyVerifier() { require(roles[msg.sender] == Role.AR || roles[msg.sender] == Role.VERIFIER || roles[msg.sender] == Role.KPP_HEAD); _; }

    // 1. Fungsi Pencatatan
    function recordPayment(string memory _npwp, uint256 _amt, string memory _code) public onlyWP {
        payCount++;
        payments[payCount] = Payment(payCount, _npwp, _amt, _code, msg.sender, Status.POSTED);
        emit PaymentLogged(payCount, msg.sender, _amt);
    }

    // 2. Fungsi Pengajuan
    function requestRestitution(uint256 _payId, uint256 _amt) public onlyWP returns (uint256) {
        require(payments[_payId].owner == msg.sender && _amt <= payments[_payId].amount);
        reqCount++;
        requests[reqCount] = Request(reqCount, _payId, _amt, 0, Status.PENDING);
        return reqCount;
    }

    // 3. Fungsi Approval (Multi-sig 2-of-3)
    function approveRequest(uint256 _reqId) public onlyVerifier {
        Request storage r = requests[_reqId];
        require(r.status == Status.PENDING);
        r.approvals++;
        if (r.approvals >= 2) r.status = Status.APPROVED;
        if (r.status == Status.APPROVED) emit RestitutionApproved(_reqId);
    }

    // 4. Fungsi Verifikasi Publik (Read)
    function verifyPayment(uint256 _id) public view returns (string memory, uint256, Status) {
        Payment memory p = payments[_id];
        return (p.npwp, p.amount, p.status);
    }

    // 5. Fungsi Pelacakan Alokasi (Read)
    function trackAllocation(string memory _code) public pure returns (string memory) {
        return string(abi.encodePacked("Dana dialokasikan ke program: ", _code));
    }
}



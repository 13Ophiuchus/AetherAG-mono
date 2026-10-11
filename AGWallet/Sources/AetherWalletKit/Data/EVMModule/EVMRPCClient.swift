import BigInt
import Foundation
import Web3Core
import web3swift

protocol EVMRPCClient: Sendable {
    func getBalance(for address: EthereumAddress) async throws -> BigUInt
    func getTransactionCount(for address: EthereumAddress) async throws -> BigUInt
    func gasPrice() async throws -> BigUInt
    func estimateGas(for transaction: CodableTransaction) async throws -> BigUInt
    func send(raw data: Data) async throws -> TransactionSendingResult
}

final class Web3EVMRPCClient: EVMRPCClient, @unchecked Sendable {
    private let web3: Web3

    init(web3: Web3) {
        self.web3 = web3
    }

    func getBalance(for address: EthereumAddress) async throws -> BigUInt {
        try await web3.eth.getBalance(for: address, onBlock: .latest)
    }

    func getTransactionCount(for address: EthereumAddress) async throws -> BigUInt {
        try await web3.eth.getTransactionCount(for: address, onBlock: .pending)
    }

    func gasPrice() async throws -> BigUInt {
        try await web3.eth.gasPrice()
    }

    func estimateGas(for transaction: CodableTransaction) async throws -> BigUInt {
        try await web3.eth.estimateGas(for: transaction)
    }

    func send(raw data: Data) async throws -> TransactionSendingResult {
        try await web3.eth.send(raw: data)
    }
}

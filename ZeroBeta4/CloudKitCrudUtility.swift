//
//  CloudKitCrudUtility.swift
//  ZeroBeta3
//
//

import CloudKit
import os.log

protocol CloudKitableProtocol: Sendable {
    init?(record: CKRecord)
    var record: CKRecord { get }
    static var recordType: String { get }
}

extension CloudKitableProtocol {
    var recordType: String { Self.recordType }
}

class CloudKitCrudUtility {
    private static let logger = Logger(subsystem: "com.example.CloudKitApp", category: "CloudKitUtility")
    
    /// Fetch records
    static func fetch<T: CloudKitableProtocol>(
        predicate: NSPredicate = NSPredicate(value: true),
        recordType: CKRecord.RecordType,
        sortDescriptions: [NSSortDescriptor]? = nil,
        resultsLimit: Int? = nil
    ) async throws -> [T] {
        var fetchedItems: [T] = []
        var queryCursor: CKQueryOperation.Cursor? = nil
        
        repeat {
            let operation: CKQueryOperation
            if let cursor = queryCursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                let query = CKQuery(recordType: recordType, predicate: predicate)
                query.sortDescriptors = sortDescriptions
                operation = CKQueryOperation(query: query)
                if let limit = resultsLimit {
                    operation.resultsLimit = limit
                }
            }
            
            // Ensure proper continuation usage
            fetchedItems += try await withCheckedThrowingContinuation { continuation in
                var batchItems: [T] = []
                
                operation.recordMatchedBlock = { recordID, result in
                    switch result {
                    case .success(let record):
                        if let item = T(record: record) {
                            batchItems.append(item)
                        }
                    case .failure(let error):
                        print("Error fetching record: \(error)")
                    }
                }
                
                operation.queryResultBlock = { result in
                    switch result {
                    case .success(let cursor):
                        queryCursor = cursor
                        continuation.resume(returning: batchItems)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                
                CKContainer.default().publicCloudDatabase.add(operation)
            }
        } while queryCursor != nil
        
        return fetchedItems
    }
    
    /// Save or update a record
    static func saveOrUpdate<T: CloudKitableProtocol>(item: T) async throws {
        let record = item.record
        print("Saving record: \(record.recordID)")

        try await withCheckedThrowingContinuation { continuation in
            CKContainer.default().publicCloudDatabase.save(record) { savedRecord, error in
                if let error = error {
                    print("Error saving record: \(error.localizedDescription)")
                    continuation.resume(throwing: error) // Properly resume with error
                } else if let savedRecord = savedRecord {
                    print("Successfully saved record: \(savedRecord.recordID)")
                    continuation.resume(returning: ()) // Properly resume with success
                } else {
                    print("Unknown error: Record not saved or returned.")
                    continuation.resume(throwing: NSError(domain: "CloudKitError", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Unknown error during saveOrUpdate."
                    ]))
                }
            }
        }
    }
    
    /// Delete a record
    static func delete<T: CloudKitableProtocol>(item: T) async throws {
        let recordID = item.record.recordID
        print("Deleting record with ID: \(recordID)")

        try await withCheckedThrowingContinuation { continuation in
            CKContainer.default().publicCloudDatabase.delete(withRecordID: recordID) { deletedRecordID, error in
                if let error = error {
                    print("Error deleting record: \(error.localizedDescription)")
                    continuation.resume(throwing: error) // Properly resume with error
                } else if let deletedRecordID = deletedRecordID {
                    print("Successfully deleted record with ID: \(deletedRecordID)")
                    continuation.resume(returning: ()) // Properly resume with success
                } else {
                    print("Unknown error: Record not deleted or returned.")
                    continuation.resume(throwing: NSError(domain: "CloudKitError", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Unknown error during delete."
                    ]))
                }
            }
        }
    }
}

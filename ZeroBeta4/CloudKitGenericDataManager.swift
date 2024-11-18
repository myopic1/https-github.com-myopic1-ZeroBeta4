//
//  CloudKitGenericDataManager.swift
//  ZeroBeta3
//
//

import CloudKit

class CloudKitGenericDataManager<T: CloudKitableProtocol>: ObservableObject {
    @Published var items: [T] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Fetch
    @MainActor
    func fetchAll(predicate: NSPredicate = NSPredicate(value: true)) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Perform the fetch entirely outside MainActor
            let fetchedItems: [T] = try await CloudKitCrudUtility.fetch(
                predicate: predicate,
                recordType: T.recordType
            )

            // Update state in MainActor
            await MainActor.run {
                self.items = fetchedItems
                print("Fetching recordType: \(T.recordType)")
                print("Fetched items: \(fetchedItems)")
            }
        } catch {
            // Handle error in MainActor
            await MainActor.run {
                self.errorMessage = "Error fetching items: \(error.localizedDescription)"
                
            }
            
        }
    
    }
    
    // MARK: - Add
    func add(item: T) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await CloudKitCrudUtility.saveOrUpdate(item: item)
            await fetchAll() // No need to pass recordType
        } catch {
            self.errorMessage = "Error adding item: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Delete
    func delete(item: T) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await CloudKitCrudUtility.delete(item: item)
            await fetchAll() // Sync with server after deletion
        } catch {
            self.errorMessage = "Error deleting item: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Update
    func update(item: T) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await CloudKitCrudUtility.saveOrUpdate(item: item)
            await fetchAll() // No need to pass recordType
        } catch {
            self.errorMessage = "Error updating item: \(error.localizedDescription)"
        }
    }
}

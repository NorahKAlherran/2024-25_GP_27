import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase Admin SDK
cred = credentials.Certificate('/Users/saraabdullah/Desktop/flutternew/android/python_script/ServiceAccountKey.json')
firebase_admin.initialize_app(cred)

# Get Firestore client
db = firestore.client()

# Replace 'your_collection_name' with the name of your collection
collection_name = "recipes"

# Define the fields to be deleted
fields_to_delete = ["dish_type", "nutrients", "rattings", "serves", "subcategory"]

def delete_fields(batch_size=50):
    docs = db.collection(collection_name).limit(batch_size).stream()

    while True:
        docs_processed = 0

        for doc in docs:
            doc_ref = db.collection(collection_name).document(doc.id)
            updates = {field: firestore.DELETE_FIELD for field in fields_to_delete}

            try:
                doc_ref.update(updates)
                print(f"Successfully deleted fields from document ID: {doc.id}")
                docs_processed += 1
            except Exception as e:
                print(f"Failed to update document ID: {doc.id}. Error: {e}")

        if docs_processed < batch_size:
            # Exit loop when fewer documents are processed (end of collection)
            print("Completed processing all documents.")
            break
        else:
            # Continue with the next batch
            docs = db.collection(collection_name).limit(batch_size).stream()

if __name__ == "__main__":
    delete_fields()

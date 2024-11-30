import firebase_admin
from firebase_admin import credentials, firestore
import time
from google.api_core.exceptions import GoogleAPICallError

cred = credentials.Certificate("/Users/saraabdullah/Desktop/flutternew/android/python_script/ServiceAccountKey.json")
app = firebase_admin.initialize_app(cred)

store = firestore.client()

def add_flag_to_documents():
    collection_ref = store.collection('users_recipes')

    # Initialize a batch
    batch = store.batch()
    batch_size = 500  
    count = 0

    docs = collection_ref.stream()
    for doc in docs:
        try:
            doc_ref = collection_ref.document(doc.id)
            batch.update(doc_ref, {'flag': "users_recipes"})  # Set the flag
            count += 1

            if count >= batch_size:
               
                batch.commit()
                print(f"Committed {batch_size} updates.")
                batch = store.batch()  # Start a new batch
                count = 0

        except Exception as e:
            print(f"Failed to update document ID: {doc.id}, Error: {e}")  # Log error

    # Commit any remaining updates
    if count > 0:
        batch.commit()
        print(f"Committed remaining {count} updates.")

    print("Flag attribute added to all documents.")

# Call the function
add_flag_to_documents()

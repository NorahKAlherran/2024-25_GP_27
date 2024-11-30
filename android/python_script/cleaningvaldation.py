import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
cred = credentials.Certificate('/Users/saraabdullah/Desktop/flutternew/android/python_script/ServiceAccountKey.json')
firebase_admin.initialize_app(cred)

# Initialize Firestore
db = firestore.client()

# Define the Firestore collection name
collection_name = 'recipes'  # Update with your collection name

# Track documents without the 'cleanedingredients' field
uncleaned_docs = []

# Retrieve all documents and check for 'cleanedingredients' field
docs = db.collection(collection_name).stream()
for doc in docs:
    data = doc.to_dict()
    if 'cleanedingredients' not in data:
        uncleaned_docs.append(doc.id)

# Output the result
if uncleaned_docs:
    print("The following documents are missing the 'cleanedingredients' field:")
    for doc_id in uncleaned_docs:
        print(f"Document ID: {doc_id}")
else:
    print("All documents are updated with the 'cleanedingredients' field.")

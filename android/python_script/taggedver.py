import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
cred = credentials.Certificate('/Users/saraabdullah/Desktop/flutternew/android/python_script/ServiceAccountKey.json')
firebase_admin.initialize_app(cred)

# Initialize Firestore
db = firestore.client()

# Define the Firestore collection name
collection_name = 'recipes'  # Ensure this is the correct collection

# Count documents missing the 'Tags' field
missing_tags_count = 0

# Retrieve all documents and check for 'Tags' field
docs = db.collection(collection_name).stream()
for doc in docs:
    data = doc.to_dict()
    if 'Tags' not in data:  # Checking for missing 'Tags'
        missing_tags_count += 1

# Output the result
print(f"Number of documents missing the 'Tags' field: {missing_tags_count}")

import firebase_admin
from firebase_admin import credentials, firestore

# Initialize the Firebase app (replace with the path to your Firebase Admin SDK JSON file)
cred = credentials.Certificate('/Users/saraabdullah/Desktop/flutternew/android/python_script/ServiceAccountKey.json')

firebase_admin.initialize_app(cred)

# Initialize Firestore
db = firestore.client()
recipes_collection = db.collection("recipes")

# Query and delete 900 documents
docs = recipes_collection.limit(900).stream()
delete_count = 0

for doc in docs:
    doc.reference.delete()
    delete_count += 1

print(f"Deleted {delete_count} documents from the 'recipes' collection.")

import firebase_admin
from firebase_admin import credentials, firestore

# Initialize the Firebase app (replace with the path to your Firebase Admin SDK JSON file)
cred = credentials.Certificate('/Users/saraabdullah/Desktop/flutternew/android/python_script/ServiceAccountKey.json')
firebase_admin.initialize_app(cred)

# Initialize Firestore
db = firestore.client()

# Count documents in "recipes" collection
recipes_collection = db.collection("recipes")
docs = recipes_collection.stream()
count = sum(1 for _ in docs)

print(f"The 'recipes' collection contains {count} documents.")

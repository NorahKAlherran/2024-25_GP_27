import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase Admin SDK
cred = credentials.Certificate('/Users/saraabdullah/Desktop/flutternew/android/python_script/ServiceAccountKey.json')
firebase_admin.initialize_app(cred)

# Firestore client
db = firestore.client()

def check_cleaned_ingredients():
    recipes_ref = db.collection("recipes")
    documents = recipes_ref.stream()

    total_docs = 0
    missing_field_docs = []
    updated_docs_count = 0

    for doc in documents:
        total_docs += 1
        data = doc.to_dict()

        # Check if "cleaned_ingredients" exists
        if "cleaned_ingredients" not in data:
            print(f"Missing 'cleaned_ingredients' in document ID: {doc.id}")
            missing_field_docs.append(doc.id)

  

    print(f"Total documents checked: {total_docs}")
    print(f"Documents missing 'cleaned_ingredients': {len(missing_field_docs)}")
    print(f"Documents updated with default 'cleaned_ingredients': {updated_docs_count}")

    return missing_field_docs

if __name__ == "__main__":
    missing_docs = check_cleaned_ingredients()

    if missing_docs:
        print("\nDocuments missing 'cleaned_ingredients':")
        for doc_id in missing_docs:
            print(f"- {doc_id}")
    else:
        print("\nAll documents have 'cleaned_ingredients' field!")

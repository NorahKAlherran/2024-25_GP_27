
import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd

# Initialize Firebase Admin SDK
cred = credentials.Certificate('/Users/saraabdullah/Desktop/flutternew/android/python_script/ServiceAccountKey.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# Specify your Firestore collection name
collection_name = "recipes"

# Export Firestore collection to CSV
def export_to_csv(collection_name, output_file):
    docs = db.collection(collection_name).stream()
    data = [doc.to_dict() for doc in docs]
    df = pd.DataFrame(data)
    df.to_csv(output_file, index=False)
    print(f"Data exported to {output_file}")

if __name__ == "__main__":
    export_to_csv(collection_name, "/Users/saraabdullah/Desktop/NEWoutput.csv")


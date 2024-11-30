import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd

# Initialize Firebase Admin SDK
cred = credentials.Certificate('/Users/saraabdullah/Desktop/flutternew/android/python_script/ServiceAccountKey.json') # Replace with your service account key file path
firebase_admin.initialize_app(cred)

# Get Firestore client
db = firestore.client()

# Function to import data from CSV to Firestore
def import_csv_to_firestore(csv_file_path, collection_name):
    # Read the CSV file into a DataFrame
    data = pd.read_csv(csv_file_path)

    # Iterate over the rows of the DataFrame
    for index, row in data.iterrows():
        # Convert row to a dictionary
        record = row.to_dict()

        # Generate a unique document ID (use Firestore's auto-generated ID or a specific field)
        doc_ref = db.collection(collection_name).document()  # Auto-generate ID
        # doc_ref = db.collection(collection_name).document(str(record['id']))  # Use a specific field as ID if needed

        # Add the record to Firestore
        doc_ref.set(record)
        print(f"Document added with data: {record}")

# Path to your CSV file
csv_file_path = "/Users/saraabdullah/Desktop/output.csv"
  # Replace with the actual path to your CSV file

# Call the function to import data
import_csv_to_firestore(csv_file_path, "recipes")

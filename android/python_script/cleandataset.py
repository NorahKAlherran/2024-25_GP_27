import firebase_admin
from firebase_admin import credentials, firestore
import re
import time


cred = credentials.Certificate('/Users/saraabdullah/Desktop/flutternew/android/python_script/ServiceAccountKey.json')
firebase_admin.initialize_app(cred)


db = firestore.client()

#common measurement 
measurement_words = {
    'cups', 'cup', 'tablespoon', 'tablespoons', 'teaspoon', 'teaspoons', 
    'ml', 'g', 'oz', 'pound', 'lb', 'grams', 'kg', 'liter', 'liters', 'pinch', 'dash'
}


ingredient_pattern = re.compile(r'\b[a-zA-Z]+\b')

#Function to extract clean ingredients
def clean_ingredients(ingredient):
    words = ingredient_pattern.findall(ingredient)
    ingredients_only = [word for word in words if word.lower() not in measurement_words]
    return ', '.join(ingredients_only)


collection_name = 'recipes'  
batch_size = 500  


docs = db.collection(collection_name).limit(batch_size).stream()
last_doc = None

while docs:

    for doc in docs:
        data = doc.to_dict()
        if 'ingredients' in data:
           
            cleaned_ingredients = clean_ingredients(data['ingredients'])
            
            # Update the document with the new 'cleanedingredients' field
            db.collection(collection_name).document(doc.id).update({
                'cleanedingredients': cleaned_ingredients
            })
        last_doc = doc 

 
    if last_doc:
        docs = db.collection(collection_name).start_after(last_doc).limit(batch_size).stream()
    else:
        break  

print("All documents updated with 'cleanedingredients' field.")
 
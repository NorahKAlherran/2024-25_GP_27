import firebase_admin
from firebase_admin import credentials, firestore
import re


cred = credentials.Certificate('/Users/saraabdullah/Desktop/flutternew/android/python_script/ServiceAccountKey.json')
firebase_admin.initialize_app(cred)


db = firestore.client()


additional_words_to_remove = {  'tbsp', 'tsp', 'etc', 'slice', 'slices', 'and', 'into', 'cubes', 'good', 
    'quality', 'shapes', 'chopped', 'finely', 'fresh', 'ground', 'handful', 
    'halves', 'pieces', 'whole', 'to', 'taste', 'grated', 'small', 'large', 
    'medium', 'pinch', 'optional', 'of', 'diced', 'for', 'cooking', 'or', 'such as'}  



def further_clean_ingredients(cleaned_ingredients):
    words = cleaned_ingredients.split(', ')
    refined_ingredients = [word for word in words if word.lower() not in additional_words_to_remove]
    return ', '.join(refined_ingredients)


collection_name = 'recipes'
batch_size = 500 



last_doc = None 

while True:
    
    query = db.collection(collection_name).limit(batch_size)
    if last_doc:
        query = query.start_after(last_doc)

    
    docs = list(query.stream()) 

    
    if not docs:
        print("All documents processed.")
        break

   
    for doc in docs:
        data = doc.to_dict()
        if 'cleanedingredients' in data:
          
            further_cleaned = further_clean_ingredients(data['cleanedingredients'])
           
            db.collection(collection_name).document(doc.id).update({
                'cleanedingredients': further_cleaned
            })

       
        last_doc = doc  
print("Data cleaning and update completed.")

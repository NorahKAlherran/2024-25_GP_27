import ast
import nltk
from nltk.corpus import wordnet as wn
from nltk.tokenize import word_tokenize
from firebase_admin import credentials, firestore, initialize_app
import time

# Initialize Firebase
cred = credentials.Certificate("C:/Users/Noni/Desktop/flutter_application_1/test-4a74f-firebase-adminsdk-6l6tn-2267a1e863.json")
initialize_app(cred)
db = firestore.client()

nltk.download('wordnet')
nltk.download('punkt')
def is_food_noun(word):
    """
    Check if a word is a food-related noun using WordNet.
    """
    for synset in wn.synsets(word, pos=wn.NOUN):  # Check only noun 
        if synset.lexname() == 'noun.food':
            return True
    return False

def clean_ingredients(ingredients_list):
    """
    Clean the ingredients list to retain only food-related nouns.
    """
    cleaned = []
    for ingredient in ingredients_list:
        words = word_tokenize(ingredient)  
        for word in words:
            word_lower = word.lower()
            if is_food_noun(word_lower):  # Dynamically check if it's a food noun
                cleaned.append(word_lower)
    return list(set(cleaned))  # Remove duplicates

def safely_parse_ingredients(raw_ingredients):
    """
    Safely parse the ingredients string into a Python list.
    Handles cases where the format is not a valid Python literal.
    """
    try:
       
        parsed_ingredients = ast.literal_eval(raw_ingredients)
        if isinstance(parsed_ingredients, list):
            return parsed_ingredients
    except (SyntaxError, ValueError):
        pass 
   
    if raw_ingredients.startswith("[") and raw_ingredients.endswith("]"):
        # Remove brackets and split manually
        raw_ingredients = raw_ingredients[1:-1]  # Strip brackets
        items = raw_ingredients.split(",")  # Split by commas
        return [item.strip() for item in items]

    print(f"Failed to parse ingredients: {raw_ingredients}")
    return None

def update_document_with_retry(doc_ref, data, retries=3, delay=2):
    """
    Retry logic for updating Firestore documents.
    """
    for attempt in range(retries):
        try:
            doc_ref.update(data)
            return True
        except Exception as e:
            print(f"Retry {attempt + 1}/{retries} failed for {doc_ref.id}: {e}")
            time.sleep(delay)
    print(f"Failed to update document {doc_ref.id} after {retries} retries.")
    return False

def process_and_update_firestore():
    """
    Fetch ingredients from Firestore in batches, clean them, and update Firestore.
    """
    recipes_ref = db.collection('recipes')  
    batch_size = 100  # Number of documents to process in each batch
    last_doc = None  # Keep track of the last document in the previous batch

    while True:
        # Fetch a batch of documents
        query = recipes_ref.order_by('name').limit(batch_size)
        if last_doc:
            query = query.start_after(last_doc)

        recipes = list(query.stream())  

        if not recipes:
            break  

        for recipe in recipes:
            try:
                data = recipe.to_dict()
                if 'ingredients' in data:  # Check if the ingredients field exists
                    raw_ingredients = data['ingredients']
                    if isinstance(raw_ingredients, str):  # Convert string to list
                        ingredients_list = safely_parse_ingredients(raw_ingredients)
                        if not ingredients_list:  # Skip if parsing failed
                            print(f"Skipping recipe {recipe.id}: invalid ingredients format")
                            continue

                    # Clean the ingredients list
                    cleaned = clean_ingredients(ingredients_list) 
                    # Update Firestore with the cleaned ingredients
                    update_document_with_retry(
                        recipes_ref.document(recipe.id),
                        {'cleaned_ingredients': cleaned}
                    )
                    print(f"Processed recipe {recipe.id}: {cleaned}")
            except Exception as e:
                print(f"Failed to process recipe {recipe.id}: {e}")

        last_doc = recipes[-1]

    print("All recipes processed.")

if __name__ == "_main_":
    process_and_update_firestore()
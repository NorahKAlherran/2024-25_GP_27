import re
import nltk
from nltk.corpus import wordnet as wn
from nltk.tokenize import word_tokenize
from firebase_admin import credentials, firestore, initialize_app
import time

# Initialize Firebase
cred = credentials.Certificate('/Users/saraabdullah/Desktop/flutternew/android/python_script/ServiceAccountKey.json')
initialize_app(cred)
db = firestore.client()

# Download required NLTK data
nltk.download('wordnet')
nltk.download('punkt')

def get_food_words():
    """Return a set of all food-related words from WordNet."""
    food_words = set()
    for synset in wn.all_synsets('n'):
        if synset.lexname() == 'noun.food':  # Check if it belongs to the 'food' category
            food_words.update(synset.lemma_names())
    return food_words

def clean_ingredient_entry(entry):
    """
    Clean individual ingredient entry by removing non-alphabetic characters.
    """
    words = word_tokenize(entry)
    cleaned_words = [word.lower() for word in words if word.isalpha()]  # Keep only alphabetic words
    return " ".join(cleaned_words)  # Return as a single cleaned string

def clean_ingredients(ingredients_list, food_words):
    """Clean the ingredients list to retain only food-related nouns."""
    cleaned = []
    for ingredient in ingredients_list:
        cleaned_entry = clean_ingredient_entry(ingredient)  # Clean individual entry
        # Check if the cleaned entry exists as a food-related noun
        if cleaned_entry in food_words:
            cleaned.append(cleaned_entry)
    return list(set(cleaned))  # Remove duplicates

def safely_parse_ingredients(raw_ingredients):
    """
    Safely parse the ingredients string into a Python list.
    Handles cases where the format is not a valid Python literal.
    """
    try:
        # Check if the string is in list-like format (e.g., "[item1, item2]")
        if raw_ingredients.startswith("[") and raw_ingredients.endswith("]"):
            # Remove surrounding brackets and split manually
            raw_ingredients = raw_ingredients[1:-1]  # Strip brackets
            items = re.split(r',\s*', raw_ingredients)  # Split by commas
            return [item.strip() for item in items]
        else:
            raise ValueError("Ingredients not in valid list format")
    except Exception as e:
        print(f"Failed to parse ingredients: {e}")
        return None

def listen_for_new_recipes():
    """Listen for newly created recipes and add cleaned_ingredients dynamically."""
    food_words = get_food_words()
    collection_ref = db.collection('users_recipes')

    # Callback to process added recipes
    def on_snapshot(col_snapshot, changes, read_time):
        for change in changes:
            if change.type.name == 'ADDED':  # Process newly added documents
                doc = change.document
                doc_id = doc.id
                data = doc.to_dict()

                if 'ingredients' in data:  # Check if the ingredients field exists
                    raw_ingredients = data['ingredients']
                    if isinstance(raw_ingredients, str):  # Convert string to list
                        ingredients_list = safely_parse_ingredients(raw_ingredients)
                        if not ingredients_list:  # Skip if parsing failed
                            print(f"Skipping recipe {doc_id}: invalid ingredients format")
                            continue

                    # Clean the ingredients list
                    cleaned = clean_ingredients(ingredients_list, food_words)

                    # Update Firestore with the cleaned ingredients
                    try:
                        collection_ref.document(doc_id).update({'cleaned_ingredients': cleaned})
                        print(f"Added cleaned_ingredients to recipe {doc_id}: {cleaned}")
                    except Exception as e:
                        print(f"Failed to update recipe {doc_id}: {e}")

    # Attach the listener to the Firestore collection
    collection_ref.on_snapshot(on_snapshot)
    print("Listening for new recipes...")

# Run the listener
if __name__ == "_main_":
    listen_for_new_recipes()
    # Keep the script running to monitor Firestore in real-time
    while True:
        time.sleep(1)
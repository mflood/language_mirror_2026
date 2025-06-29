from uuid import uuid4
import yaml
import json

# Helper function to create UUIDs
def make_id():
    return str(uuid4())


def make_collection_bundle(collection_object):
    
    collection_id = make_id()

    collection = {
            "id": collection_id,
            "name": collection_object['name'],
            "groupOrder":  [i['name'] for i in collection_object['groups']],
        }

    memberships = []
    track_bundles = []

    for group in collection_object['groups']:
        for track in group['tracks']:
            track_id = make_id()
            track_object = {
                "id": track_id,
                "title": track.replace(".mp3", "").replace("_", " "),
                "fileURL": track,
                "sourceType": "textbook",
                "duration": 1.3,
                "tags": ["level:beginner"]
            }
            track_bundle =  {
                "track": track_object,
                "arrangements": []
            }
            track_bundles.append(track_bundle)
            membership = {
                "collectionId": collection_id,
                "trackId": track_id,
                "group": group['name'],
            }
            memberships.append(membership)
            

    collection_bundle = {
        "collection": collection,
        "memberships": memberships,
        "tracks": track_bundles,
    }

    return collection_bundle

collection_bundles = []
with open("bundle.yaml") as handle:
    data = yaml.safe_load(handle.read())
    for collection in data['collections']:
        collection_bundles.append(make_collection_bundle(collection))
        

output_path = "data.json"
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(collection_bundles, f, ensure_ascii=False, indent=2)

print(output_path)

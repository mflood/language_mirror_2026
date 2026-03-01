
1. Generate the bundle.json
```
python bundle_pipeline/scripts/init_bundle.py --source-s3 s3://turned.korean/integrated_korean_beginning_1 --language-code ko-KR --bundle-title "Integrated Korean Beginner 1 Yay" --bundle-id int-kor-beg-01-r1 --author 'Maybe Some Press' --gpt-model gpt-5.2 --publish-config ./bundle_publish_config.yaml --work-root ./myworkroot
```

2. Download the files
```
 python bundle_pipeline/scripts/download_audio.py --bundle-id int-kor-beg-01-r1 --work-root myworkroot
```

Manually remove files you do not want included...

TODO: have script take argument for files to include.


3. Extract audio to text

```
python3 bundle_pipeline/scripts/transcribe_whisper.py --bundle-id int-kor-beg-01-r1 --work-root myworkroot 
```

4. Assemble the final manifest

```
python3 bundle_pipeline/scripts/assemble_manifest.py  --bundle-id int-kor-beg-01-r1 --work-root myworkroot
```

5. Publish the bundle

```
python3 bundle_pipeline/scripts/publish_bundle.py --bundle-id int-kor-beg-01-r1 --work-root myworkroot
python3 bundle_pipeline/scripts/publish_bundle.py --bundle-id int-kor-beg-01-r1 --work-root myworkroot --dryrun --verbose
```



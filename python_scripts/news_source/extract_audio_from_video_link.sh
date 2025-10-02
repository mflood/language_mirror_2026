# ffmpeg -i "https://news.kbs.co.kr/news/pc/view/embedVideo.do?vodUrl=/newsmp4/news9_history/1991/19910110/1500K_new/330.mp4" -vn -c:a libmp3lame -b:a 192k "audio.mp3"


# https://news.kbs.co.kr/news/pc/view/embedVideo.do?vodUrl=/newsmp4/news9_history/1991/19910110/1500K_new/330.mp4
# https://news.kbs.co.kr/news/pc/view/view.do?ncd=3700917



ffmpeg -i  /Users/matthewflood/Downloads/330.mp4  -vn -c:a libmp3lame -b:a 192k "audio.mp3"

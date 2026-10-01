# 모바일 후속 서버 계약과 완료 기준

2026-10-02 웹 `pubg-map-app-local`과 앱 작업트리의 실제 API 코드를 기준으로 정리했다. 아래의 **현재 계약**은 로컬 구현 확인 결과이며 운영 배포·DB/RPC/RLS·Storage 설정·실제 쓰기 성공을 뜻하지 않는다. **제안 계약**은 아직 구현되지 않은 서버 후속 작업이다. 이번 앱 작업에서 웹 서버 파일은 변경하지 않았다.

앱에 연결한 기능은 게시판 분류 별칭·답글, 최근 경기 AI v2 사실 카드, 공개 FAQ·인증 문의 목록/상세·일반 문의 작성·추가 메시지·기존 증빙 열람이다. 게시판 이미지 작성·회원 수정/삭제/추천/신고·신규 문의 첨부/개인정보 문의는 완료로 집계하지 않는다.

## 1. 게시판 분류와 저장: 우선순위 1

### 현재 계약

- `GET /api/mobile/board/posts?limit=20&cursor=...&q=...&category=...`: 공개 published 글만 조회한다. `category`는 DB 값과 정확히 비교하고 응답은 `{items,hasMore,nextCursor}`다. 웹 분류는 `배그 소식`, `자유`, `듀오/스쿼드 모집`, `클랜홍보`, `제보/문의`인데 기존 앱 데이터에는 `free/strategy/question/notice/clan` 및 `공략/질문/공지/클랜`이 남아 있다.
- `POST /api/mobile/board/posts`: Bearer 또는 쿠키 회원 인증. JSON `{title,content,category}`를 받는다. 제목 2~80자, 본문 2~5000자. 허용 분류는 `free,strategy,question,notice,clan,자유,공략,질문,공지,클랜`이다. 미지원 분류를 보내면 400이 아니라 `free`로 저장한다. `image_url`, `imageUrl` 또는 이미지 본문은 400으로 거절한다. 현재 성공 응답은 `{success:true,id:number}`다.
- 앱은 `category`를 생략한 전체 목록을 조회하고 별칭으로 분류하며 서버의 원래 `nextCursor/hasMore`를 유지한다. 분류와 맞는 글이 없는 페이지에도 더 보기를 남긴다. `free→자유`, `strategy→공략`, `question→질문`, `notice→공지`, `clan/클랜→클랜홍보`를 지원한다. 기존 `질문`을 웹 `제보/문의`로, `공지`를 `배그 소식`으로 임의 합치지 않는다.
- 앱 작성은 현재 서버가 허용하는 `자유/공략/질문/클랜`만 사용한다. 읽기 필터에 모집·제보 분류가 있다고 해서 해당 분류 작성도 가능한 것은 아니다.

근거: [목록 필터](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/mobile/board/posts/route.ts:125), [작성 검증](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/mobile/board/posts/route.ts:154), [앱 별칭](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/bgms-mobile-app/lib/features/board/board_categories.dart:1).

### 제안 계약과 완료 기준

서버에서 공통 분류와 legacy 별칭을 정규화하고 목록 조회 시 모든 해당 별칭을 함께 검색한다. 잘못된 새 분류는 `free`로 조용히 변환하지 말고 400을 반환한다. 기존 앱 작성글을 재분류할지 읽기 별칭으로 유지할지는 서버 데이터 정책으로 확정한다. 제목·본문 길이는 웹 저장 계약의 50자/300000자와 모바일의 80자/5000자를 그대로 혼용하지 말고 소비자 API 한도를 확정한다.

완료 기준은 웹 작성 `자유`와 기존 앱 `free` 글이 같은 필터에 나오고, 검색·공지 정렬·커서 페이지 경계에 누락/중복이 없으며, 모집·클랜·제보를 작성한 뒤 해당 분류에서 왕복 확인하는 것이다. 공개 목록과 회원 저장은 별도 인증 테스트를 한다.

## 2. 게시판 이미지 저장과 회원 수정: 우선순위 1

### 이미 존재하는 업로드 API

모든 아래 API는 `withAuthGuard`로 Bearer와 쿠키를 지원한다. UUID는 서버 검증 규칙을 따른다.

| 메서드·경로 | 요청 JSON | 현재 성공 응답 |
|---|---|---|
| `POST /api/board/images/reserve` | `{mimeType:"image/jpeg",byteSize:number}` | `{imageId,bucketId,storageKey,token,publicUrl}` |
| `POST /api/board/images/complete` | `{imageId:uuid}` | `{imageId,publicUrl}` |
| `POST /api/board/images/release` | `{imageIds:uuid[]}` | `{released:number,deferred:number}` |

형식은 PNG/JPEG/WebP, 파일당 최대 **1,572,864바이트**, release는 1~20개다. 업로드는 반환된 `bucketId/storageKey/token`으로 Storage 서명 업로드를 사용하며 `upsert:false`다. 버킷은 `board-images-v2`다. complete와 글 저장은 서로 다른 단계이며 업로드 성공만으로 게시글에 연결된 것이 아니다. release의 `deferred`를 전부 삭제 성공으로 표시하면 안 된다.

근거: [업로드 필드와 제한](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/lib/board/imageStorageContract.ts:1), [예약/완료 응답](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/lib/board/imageStorage.server.ts:41).

### 현재 웹 저장·수정 계약과 연결 장애

`POST /api/posts/write`는 쿠키만 읽는 `withOptionalAuth`를 사용한다. Bearer만 보내는 앱 사용자는 회원으로 인식되지 않는다. 이미지를 포함한 비회원 작성은 거절하고 비회원 수정은 401로 거절한다. 회원 경로에서는 현재 body의 `user_id`가 인증 사용자 ID와 같아야 한다(관리자 예외). 앱의 회원 수정 화면을 이 URL에 연결하는 것만으로 해결되지 않는다.

웹 요청 필드는 다음과 같다. `editingPostId`가 없으면 작성, 있으면 수정이다.

```json
{
  "title": "제목",
  "content": "서버에서 정화할 HTML",
  "category": "자유",
  "user_id": "현재 웹 계약의 회원 ID",
  "editingPostId": 123,
  "expectedRevision": 2,
  "contentImageIds": ["업로드 완료한 이미지 UUID"],
  "thumbnailImageId": null,
  "image_url": null,
  "is_notice": false,
  "discord_url": "",
  "discord_channel_id": null,
  "clan_info": null
}
```

작성 때 `expectedRevision`은 null/생략이다. 수정 때는 0 이상의 safe integer가 필수다. `contentImageIds`는 최대 20개, thumbnail은 UUID/null이다. 웹 제목은 최대 50자, HTML 본문 최대 300000자다. `write_board_post_with_images` RPC를 사용하고 성공 응답은 **`{success:true,data:{id,revision}}`**로 현재 모바일 작성 응답과 다르다. revision 충돌 409, 수정 권한 없음 403, 글 없음 404, 저장 장애 503이다.

근거: [필드·revision 검증](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/posts/write/route.ts:121), [쿠키 인증](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/posts/write/route.ts:259), [RPC·응답](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/posts/write/route.ts:484).

### 필요한 서버 변경과 완료 기준

기존 웹 저장에 Bearer를 추가하거나 모바일 저장 API를 확장하되 같은 이미지 소유권·참조 연결·revision RPC를 사용한다. 인증 사용자 ID는 서버 세션에서 결정하며 소비자 앱에 관리자 권한을 전달하지 않는다. 모바일 공개 상세는 현재 contentText/imageUrls만 내려주고 소유 여부/revision/수정용 본문은 없으므로 별도 인증 읽기 계약이 필요하다.

**제안**: `GET /api/mobile/board/posts/{id}/edit`로 본인 수정 데이터 `{id,title,content,category,revision,contentImageIds,thumbnailImageId,canEdit}`를 private/no-store로 제공하고, `PATCH /api/mobile/board/posts/{id}`에 `{title,content,category,expectedRevision,contentImageIds,thumbnailImageId}`를 받는다. 현재 이 GET/PATCH는 존재하지 않는다. 신규 작성 응답과 수정 응답은 `{success:true,data:{id,revision}}` 같은 정본으로 합의하되 기존 모바일 응답과의 호환도 처리한다.

완료 기준: 완료한 본인 이미지 저장·수정 후 유지, 타인의 이미지/미완료 이미지 거절, 충돌 409에서 본문 보존·재조회, 작성 취소 시 미연결 이미지 release, 연결된 이미지를 취소 정리로 지우지 않음, 네트워크 실패 재시도의 중복 작성 정책 확정. 운영 RPC·버킷·정리 작업 확인과 실기기 사진 선택/회전/대용량 메모리 검증은 별도다.

## 3. 회원 삭제·추천·신고: 우선순위 2

### 현재 계약

- `POST /api/board/posts/delete`의 `{postId,password}` 및 `POST /api/board/comments/delete`의 `{commentId,password}`는 **비회원 비밀번호 삭제 전용**이다. 회원 데이터는 403으로 거절한다. 웹 회원 삭제는 브라우저 Supabase `.delete()`다. 웹 UI는 관리자 외 사용자의 댓글 달린 글 삭제를 막지만, 이것을 소비자 API에서 확정된 정책으로 취급하면 안 된다.
- 웹 추천은 Supabase `post_likes` 조회/insert와 `increment_likes(row_id)` RPC다. 현재 앱 소비자용 추천 API는 없다.
- `POST /api/board/report`는 `{target_type:"post"|"comment",target_id:number,reason:string,detail?:string}`를 받는다. 쿠키 선택 인증이므로 Bearer만 보내면 신고는 비회원으로 처리되고 `reporter_id`가 null이다. 같은 IP·대상 중복은 409다. 현재 성공은 `{success:true,message}`다.

근거: [비회원 글 삭제](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/board/posts/delete/route.ts:37), [회원 댓글 삭제](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/components/board/BoardDetailClient.tsx:346), [신고 인증과 저장](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/board/report/route.ts:52).

### 제안 계약과 완료 기준

회원 삭제를 별도 소비자 API로 제공할 경우 **제안** `DELETE /api/mobile/board/posts/{id}`, `DELETE /api/mobile/board/posts/{postId}/comments/{commentId}`는 Bearer 필수, 본인·대상 관계 검증과 연관 댓글/좋아요/이미지 처리 정책을 서버가 집행한다. 현재 이 DELETE들은 없다. 댓글이 있는 글의 삭제 허용 여부와 소프트 삭제/답글 보존 정책을 먼저 확정한다. 성공 `{success:true}`, 본인 권한 없음 403, 대상 없음 404, 정책상 충돌 409로 합의한다.

추천은 **제안** `POST /api/mobile/board/posts/{id}/likes`에서 중복 방지와 카운트 갱신을 하나의 서버 원자 연산으로 처리하고 `{liked:true,likes:number}`를 반환한다. 현재 이 경로는 없다. 신고는 기존 `/api/board/report`에 Bearer 선택 인증을 추가하거나 별도 모바일 경로를 제공해 로그인 신고자의 ID를 보존한다. DB 저장 실패를 성공으로 응답하지 않는 것도 완료 기준이다.

타인의 글/댓글 삭제·위조 작성자 ID·교차 게시글 댓글 ID는 거절하고 관리자 API를 앱이 대신 호출하지 않는다. 추천 동시 클릭/재시도에서 중복 레코드와 카운트 불일치가 없고 신고 재시도·저장 장애 응답도 테스트한다.

## 4. 댓글 50개 초과·답글 알림: 우선순위 1

현재 `GET /api/mobile/board/posts/{id}`는 댓글을 `created_at ASC`로 최대 50개만 반환한다. `parentId`는 있지만 전체 개수·댓글 커서는 없다. `POST /api/mobile/board/posts/{id}/comments`는 Bearer/쿠키 인증으로 `{content,parent_id?:number|null}`를 받고, 본문 1~1000자·같은 게시글의 부모 댓글을 검증하며 성공 `{success:true,id}`를 반환한다. 앱에는 답글 작성·부모 표시와 50개 제한 안내가 추가됐으나 51번째 이후 댓글이 실제로 조회되는 것은 아니다.

일반 웹 `/api/board/comments`는 댓글 저장 후 게시글/부모 댓글 작성자에게 notifications를 생성하지만 모바일 경로에는 해당 삽입이 없다. 답글 UI만 구현해도 동일한 알림 동작이 생기지 않는다.

**제안**: `GET /api/mobile/board/posts/{id}/comments?cursor=...&limit=...`에 `{items,nextCursor,hasMore,totalCount}` 및 각 항목 `{id,parentId,author,content,createdAt}`를 제공한다. 현재 이 GET은 없다. 최신 댓글 이동 또는 부모를 포함한 스레드 조회 정책을 정하고, 부모가 다른 페이지에 있어도 답글 대상을 식별할 수 있어야 한다. 모바일 댓글 저장과 웹 댓글 저장이 같은 수신자/자기 자신 제외 규칙을 사용하도록 알림 생성을 공통화한다. 알림 실패와 댓글 저장 성공을 혼동해 중복 댓글을 만들지 않는 정책이 필요하다.

완료 기준: 0/49/50/51개 및 여러 계층 답글에서 조회·계층·전체 개수가 맞고 새 댓글을 쓴 직후 결과를 확인할 수 있음, 커서 페이지에 누락/중복 없음, 본인 댓글은 자신에게 알리지 않음, 부모 작성자/게시글 작성자 선택 규칙과 웹/모바일 알림 일치.

근거: [50개 제한](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/mobile/board/posts/[postId]/route.ts:86), [모바일 부모 검증](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/mobile/board/posts/[postId]/comments/route.ts:34), [웹 알림](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/board/comments/route.ts:287).

## 5. 문의 신규 첨부와 개인정보 요청: 우선순위 2

### 서버에 이미 존재하는 계약

| 메서드·경로 | 요청 | 성공 응답·제약 |
|---|---|---|
| `GET /api/support/faqs` | query `category?:stats/account/community/feature`, `q?:string` | `{faqs:[...]}`, 공개 |
| `GET /api/support/tickets` | Bearer | `{tickets:[...]}`, 본인 문의 |
| `GET /api/support/tickets/{uuid}` | Bearer | `{ticket:{...,messages:[],attachments:[]}}`, 본인 문의·private/no-store |
| `POST /api/support/tickets` | `{category,subject,body,attachmentIds:uuid[],platform?,nickname?}` | 201 `{ticket:{id,...}}` |
| `POST /api/support/tickets/{uuid}/messages` | JSON `{body}`, Bearer, `Idempotency-Key:uuid` 헤더 | 201 `{message:{...}}`, 같은 키의 다른 본문 409 |
| `POST /api/support/player-target` | `{platform:"steam"|"kakao",nickname:string}` | `{target:{platform,requestedNickname,canonicalNickname,accountId}}`, Bearer |
| `POST /api/support/attachments/reserve` | `{mimeType,byteSize,originalName}` | `{attachmentId,bucketId,storageKey,token}`, Bearer |
| `POST /api/support/attachments/complete` | `{attachmentId:uuid}` | `{attachmentId,status:"ready"}`, Bearer |
| `GET /api/support/attachments/{uuid}/url` | Bearer | `{signedUrl,expiresIn:300}`, 소유/접근 검증 |

문의 분류는 `privacy/account/community/bug/other`, 제목 1~120자, 내용·추가 메시지 1~5000자, 24시간 문의 생성 최대 5개다. 첨부는 PNG/JPEG/WebP, 파일당 3MiB·최대 3개·총 9MiB, originalName 최대 255자다. 버킷 `support-evidence`는 비공개며 게시판 publicUrl 방식을 쓰면 안 된다. 예약→반환된 경로의 `uploadToSignedUrl(...,upsert:false,contentType:...)`→complete 순서를 사용한다. 이미 연결된/다른 사용자의/만료된 첨부 ID는 새 문의에 사용할 수 없다.

`privacy`는 **platform·nickname·증빙 1개 이상이 필수**이며 생성 시 서버가 플레이어를 재확인한다. 클라이언트의 확인 결과만 믿고 저장하지 않는다. 개인정보 요청은 `verificationStatus:pending`, 나머지는 `not_required`를 서버에서 정한다. 중복 처리 중 문의는 409, 플레이어 없음 404, 사용량 초과 429, 장애 503이다.

근거: [문의 검증](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/lib/support/validation.ts:29), [서버 제한](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/lib/support/contracts.ts:3), [예약·완료](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/lib/support/attachmentStorage.server.ts:145), [메시지 헤더](/Users/kangheesung/10-19_개발/13_프로젝트/13.01_PUBG_지도_서비스/pubg-map-app-local/app/api/support/tickets/[id]/messages/route.ts:19).

### 남은 앱 작업과 완료 기준

새 문의 사진 선택 의존성과 iOS/Android 네이티브 사진 선택을 도입하고 읽은 바이트·MIME·크기를 검증한다. HEIC는 현재 서버 계약에 없으므로 PNG/JPEG/WebP로 변환하거나 명확히 거절한다. 파일 경로를 사용자가 직접 입력하게 하는 방식으로 사진 선택 완료를 대신하지 않는다. 앱은 아직 신규 첨부를 지원하지 않고 일반 문의 작성만 제공하며 개인정보/증빙 문의는 외부 웹 고객센터로 안내한다. 기존 첨부 열람은 앱에서 열 때마다 새 signedUrl을 요청한다.

서버의 공개 배포·RPC·비공개 버킷을 확인한 뒤 파일별 예약·업로드·완료 상태, 선택 취소와 일부 실패, 전송 중 계정 변경, 미연결 첨부의 만료 정리를 확인한다. support에는 게시판 release와 같은 공개 취소 API가 없으며 미연결 첨부는 코드상 24시간 보존 대상으로 정리한다. 정리 함수가 운영 스케줄로 실행되는지는 별도 확인해야 한다. 앱이 임의로 Storage 삭제를 우회 호출하지 않는다. 필요하면 본인 미연결 첨부 해제 API를 서버에서 합의하거나 기존 만료 정리 정책을 소비자 UX에 반영한다.

완료 기준: 3개/초과 개수·3MiB 초과·HEIC·취소·업로드 실패·complete 실패·만료·타인 첨부 거절, 개인정보 플레이어 확인과 증빙 포함 생성, 로그아웃 시 개인 내용 제거, 메시지 실패 재시도의 같은 UUID 재사용 및 본문 변경 시 새 키, 증빙 URL 만료 후 재발급. 사진 선택과 대용량 이미지 메모리 검증은 iOS와 Android 둘 다 수행한다.

## 6. 검증 구분

앱의 가짜 HTTP/위젯 테스트는 경로·JSON·Bearer·Idempotency-Key·상태 파싱·계정 변경 응답 무시를 확인하는 계약 검증이다. 운영 서비스의 OAuth 복귀·RLS·Storage·RPC·알림·실제 작성 성공을 대신하지 않는다. 게시판 사진 저장은 업로드 API만 성공해도 완료가 아니며, support API 코드가 있다는 사실만으로 운영 배포 완료를 표시하지 않는다.

최종 운영 검증은 승인된 테스트 계정과 테스트 데이터로 Android/iOS 로그인→선택/작성→조회→수정/삭제→정리까지 왕복 확인하고 기록한다. 비밀키·서비스 역할 키는 앱에 넣지 않고 서버에 유지한다.

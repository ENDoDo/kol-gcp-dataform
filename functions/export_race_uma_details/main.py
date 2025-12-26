import os
import hashlib
import csv
import io
import json
import logging
import ftplib
import functions_framework
from google.cloud import bigquery
from google.cloud import secretmanager
import datetime

# ログ設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 環境変数
PROJECT_ID = os.environ.get("PROJECT_ID")
DATASET_ID = os.environ.get("DATASET_ID") # 例: kolbi_analysis または kolbi_analysis_stg
SECRET_USER = os.environ.get("SECRET_USER") # ユーザー名のシークレットリソースID
SECRET_PASS = os.environ.get("SECRET_PASS") # パスワードのシークレットリソースID
STATE_TABLE_NAME = "race_uma_details_export_state"
FTP_HOST = "smartkb.mixh.jp"

def get_secret(secret_id):
    """Secret Managerからシークレット値を取得する"""
    client = secretmanager.SecretManagerServiceClient()
    name = f"{secret_id}/versions/latest"
    response = client.access_secret_version(request={"name": name})
    return response.payload.data.decode("UTF-8")

def ensure_state_table(bq_client, dataset_id, table_name):
    """状態管理テーブルが存在することを確認し、なければ作成する"""
    table_ref = f"{PROJECT_ID}.{dataset_id}.{table_name}"
    schema = [
        bigquery.SchemaField("race_code_uma_jvd", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("content_hash", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("exported_at", "TIMESTAMP", mode="REQUIRED"),
    ]
    try:
        bq_client.get_table(table_ref)
        logger.info(f"テーブル {table_ref} は既に存在します。")
    except Exception:
        logger.info(f"テーブル {table_ref} を作成しています...")
        table = bigquery.Table(table_ref, schema=schema)
        bq_client.create_table(table)
        logger.info(f"テーブル {table_ref} を作成しました。")

def calculate_hash(row):
    """行の内容のハッシュを計算し、変更を検知する"""
    # 行の値を文字列に変換し、ハッシュ化のために連結する
    # ソートして順序を一貫させる
    row_str = json.dumps(dict(row), sort_keys=True, default=str)
    return hashlib.sha256(row_str.encode('utf-8')).hexdigest()

@functions_framework.http
def export_race_uma_details(request):
    """更新されたレース詳細情報(race_uma_details)をFTPにエクスポートするHTTP Cloud Function"""
    try:
        # 1. クライアントの初期化
        bq_client = bigquery.Client(project=PROJECT_ID)

        # 2. FTP認証情報の取得
        logger.info("FTP認証情報を取得中...")
        ftp_user = get_secret(SECRET_USER)
        ftp_pass = get_secret(SECRET_PASS)

        # 3. 状態管理テーブルの確認
        ensure_state_table(bq_client, DATASET_ID, STATE_TABLE_NAME)

        # 4. 更新のクエリ
        query = f"""
            WITH CurrentDetails AS (
                SELECT
                    *
                FROM `{PROJECT_ID}.{DATASET_ID}.race_uma_details`
            ),
            State AS (
                SELECT
                    race_code_uma_jvd,
                    content_hash
                FROM `{PROJECT_ID}.{DATASET_ID}.{STATE_TABLE_NAME}`
            )
            SELECT
                c.*,
                s.content_hash as old_hash
            FROM CurrentDetails c
            LEFT JOIN State s ON c.race_code_uma_jvd = s.race_code_uma_jvd
        """

        logger.info("BigQueryで変更をクエリ中...")
        query_job = bq_client.query(query)
        rows = list(query_job.result())

        updates = []
        state_updates = []

        # CSV出力用フィールド定義
        fieldnames = [
            "race_code_uma_kol", "race_code_uma_jvd", "race_code_kol", "race_code_jvd", "keibajo_code_jvd", "keibajo_code_kol",
            "hasso_date", "kaiji", "nichiji", "race_bango", "race_bango_num", "waku_kubun", "wakuban", "umaban", "umaban_num", "umaban_even",
            "bamei", "seibetsu_code", "seibetsu_code_label", "barei", "barei_num", "futan_juryo", "futan_juryo_float",
            "blinker_shiyo_kubun", "blinker_shiyo_kubun_label", "rating", "rating_float",
            "banushimei", "banushimei_ryakusho", "ketto_toroku_bango_kol", "ketto1_f_hanshoku_toroku_bango", "ketto1_f_bamei",
            "ketto2_m_hanshoku_toroku_bango", "ketto2_m_bamei", "ketto5_mf_hanshoku_toroku_bango", "ketto5_mf_bamei", "kyuyo_riyu",
            "kishumei", "kishumei_ryakusho", "kishu_code", "kishu_tozai_shozoku_code", "kishu_tozai_shozoku_code_label",
            "kishu_minarai_code", "kishu_minarai_code_label", "kishu_norikawari_kubun", "kishu_norikawari_kubun_label",
            "kishu_shozokubasho_code", "kishu_shozokubasho_code_label", "kishu_shozoku_chokyoshi_code",
            "chokyoshi_code", "chokyoshimei", "chokyoshimei_ryakusho", "chokyoshi_shozokubasho_code", "chokyoshi_shozokubasho_code_label",
            "chokyoshi_tracen_kubun", "chokyoshi_tracen_kubun_label",
            "chokyo_flag", "chokyo_flag_label", "chokyo_kijosha", "chokyo_kijosha_equal_kishumei_flag", "chokyo_nengappi_date",
            "chokyo_basho", "chokyo_course", "chokyo_course_kubun", "chokyo_basho_course_label", "chokyo_babajotai", "chokyo_hanro_pool_kaisu_int",
            "chokyo_8f", "chokyo_8f_float", "chokyo_7f", "chokyo_7f_float", "chokyo_6f", "chokyo_6f_float", "chokyo_5f", "chokyo_5f_float",
            "chokyo_4f", "chokyo_4f_float", "chokyo_3f", "chokyo_3f_float", "chokyo_2f_float", "chokyo_1f", "chokyo_1f_float",
            "chokyo_lap_8f", "chokyo_lap_7f", "chokyo_lap_6f", "chokyo_lap_5f", "chokyo_lap_4f", "chokyo_lap_3f", "chokyo_lap_2f", "chokyo_lap_group",
            "shirushi_hanro_4f_flag", "shirushi_hanro_1f_flag", "shirushi_wood_6f_flag", "shirushi_wood_1f_flag",
            "shirushi_point", "shirushi_kubun_yosou_tansho_ninkijun", "shirushi_kubun_rank", "shirushi_shirushi_label", "shirushi_shirushi_num",
            "chokyo_ichidori", "chokyo_ichidori_label", "chokyo_ashiiro", "chokyo_ashiiro_label", "chokyo_yajirushi", "chokyo_yajirushi_label",
            "chokyo_reigai", "chokyo_awase", "chokyo_awase_kubun", "chokyo_awase_flag", "chokyo_awase_flag_label", "chokyo_tanpyo",
            "chokyo_honsu_course", "chokyo_honsu_course_num", "chokyo_honsu_hanro", "chokyo_honsu_hanro_num", "chokyo_honsu_pool", "chokyo_honsu_pool_num",
            "speed_sisu_last_1", "speed_sisu_last_1_float", "speed_sisu_last_2", "speed_sisu_last_2_float", "speed_sisu_last_3", "speed_sisu_last_3_float",
            "speed_sisu_last_4", "speed_sisu_last_4_float", "speed_sisu_last_5", "speed_sisu_last_5_float",
            "rotation1", "rotation1_label", "rotation2", "rotation2_label", "rotation3", "rotation3_label", "rotation4", "rotation4_label",
            "rotation5", "rotation5_label", "rotation6", "rotation6_label", "rotation7", "rotation7_label", "rotation8", "rotation8_label", "zensou_kankaku",
            "bataiju", "bataiju_kubun", "bataiju_zensou", "bataiju_kubun_zensou", "kyori_kubun_zensou", "kyori_extension_flag", "kyori_shortening_flag",
            "ensei_kansai_to_kantou_flag", "ensei_kantou_to_kansai_flag", "ensei_flag", "track_code1_label_dirtsiba_zensou", "siba_to_dirt_flag", "dirt_to_siba_flag",
            "record_shisu", "record_shisu_num", "zogen_sa", "zogen_sa_num", "tansho_ninkijun", "tansho_ninkijun_num", "tansho_odds", "tansho_odds_float",
            "kakutei_chakujun", "kakutei_chakujun_num", "tansho_haraimodoshi", "tansho_haraimodoshi_num", "fukusho_haraimodoshi", "fukusho_haraimodoshi_num",
            "ijo_kubun_code1", "ijo_kubun_code1_label", "ijo_kubun_code2", "ijo_kubun_code2_label", "nyusen_juni", "nyusen_juni_num", "record_flag", "record_flag_label",
            "soha_time", "soha_time_float", "soha_time_label", "chakusa_code1", "chakusa_code1_num", "chakusa_code2", "chakusa_code2_label", "chakusa_label",
            "time_sa", "time_sa_float", "zenhan_3f", "zenhan_3f_float", "kohan_3f", "kohan_3f_float",
            "corner1_juni", "corner1_juni_label", "corner2_juni", "corner2_juni_label", "corner3_juni", "corner3_juni_label", "corner4_juni", "corner4_juni_label", "corner4_ichidori", "corner4_ichidori_label",
            "race_name", "kyori_kubun", "keibajo_name", "chuo_chiho_kubun", "chuo_chiho_kubun_label", "kyosomei_15moji", "kyosomei_7moji",
            "grade_code", "grade_code_label", "jpn_flag", "jpn_flag_label", "bettei_barei_handicap_summary_code", "bettei_barei_handicap_summary_code_label", "bettei_barei_handicap_detail",
            "kyoso_joken_age_limit", "kyoso_joken_age_limit_label", "kyoso_joken_kubun", "kyoso_joken_kubun_label", "heichi_shogai_kubun", "heichi_shogai_kubun_label",
            "track_code1_dirtsiba", "track_code1_dirtsiba_label", "track_code2_LRS", "track_code2_LRS_label", "track_code3_inout", "track_code3_inout_label",
            "course_kubun", "course_kubun_label", "kyori", "toroku_tosu_num", "torikeshi_tosu_num", "tenko_code", "tenko_code_label",
            "babajotai_code", "babajotai_code_label", "pace_yosou", "pace_yosou_label", "pace_kekka", "pace_kekka_label", "race_tanpyo",
            "juryo_handicap_flag", "keibajo_komawari_curve4_flag", "keibajo_omawari_curve4_flag", "keibajo_straight_short_flag", "keibajo_straight_long_flag",
            "created", "modified"
        ]

        for row in rows:
            row_data = {field: row[field] for field in fieldnames}

            # ハッシュ計算用データ（タイムスタンプは除外）
            hash_data = row_data.copy()
            del hash_data["created"]
            del hash_data["modified"]

            current_hash = calculate_hash(hash_data)
            old_hash = row["old_hash"]

            if old_hash is None or current_hash != old_hash:
                updates.append(row_data)
                state_updates.append({
                    "race_code_uma_jvd": row_data["race_code_uma_jvd"],
                    "content_hash": current_hash
                })

        logger.info(f"{len(updates)} 件の更新が見つかりました。")

        if not updates:
            return "更新はありませんでした。", 200

        # 5. CSV生成とFTPアップロード
        CHUNK_SIZE = 1000
        table_name = "race_uma_details"

        # hasso_date (YYYY/MM/DD HH:MM:SS) から YYYYMMDD を抽出してMin/Maxを取得
        all_dates = []
        for u in updates:
            dt = u["hasso_date"]
            if isinstance(dt, str):
                 dt = datetime.datetime.strptime(dt, '%Y/%m/%d %H:%M:%S')
            elif isinstance(dt, datetime.date):
                 # date型の場合もあるのでdatetimeへ変換（時刻00:00:00）
                 dt = datetime.datetime(dt.year, dt.month, dt.day)

            all_dates.append(dt.strftime('%Y%m%d'))

        min_date = min(all_dates)
        max_date = max(all_dates)

        # データをチャンクに分割
        chunks = [updates[i:i + CHUNK_SIZE] for i in range(0, len(updates), CHUNK_SIZE)]
        total_parts = len(chunks)

        logger.info(f"FTPホスト {FTP_HOST} へアップロード中... (合計 {len(updates)} 件 - {total_parts} ファイル)")

        try:
            with ftplib.FTP(FTP_HOST) as ftp:
                ftp.login(user=ftp_user, passwd=ftp_pass)

                # ディレクトリ移動（必要に応じて環境変数に追加）
                # ftp_directory = os.environ.get("FTP_DIRECTORY")
                # if ftp_directory: ...

                for i, chunk in enumerate(chunks):
                    # ファイル名の生成
                    if total_parts > 1:
                        # 分割あり: {table_name}_{from}_{to}_part{NNN}.csv
                        part_num = i + 1
                        filename = f"{table_name}_{min_date}_{max_date}_part{part_num:03d}.csv"
                    else:
                        # 分割なし: {table_name}_{from}_{to}.csv
                        filename = f"{table_name}_{min_date}_{max_date}.csv"

                    logger.info(f"CSVを生成中... ({filename})")
                    csv_buffer = io.StringIO()
                    writer = csv.DictWriter(csv_buffer, fieldnames=fieldnames)
                    writer.writeheader()
                    writer.writerows(chunk)
                    csv_content = csv_buffer.getvalue().encode('utf-8')

                    bio = io.BytesIO(csv_content)
                    ftp.storbinary(f"STOR {filename}", bio)
                    logger.info(f"{filename} のアップロードに成功しました。")

        except Exception as e:
            logger.error(f"FTPアップロードに失敗しました: {e}")
            return f"FTPアップロード失敗: {e}", 500

        # 7. 状態管理テーブルの更新
        logger.info("状態管理テーブルを更新中...")
        if state_updates:
            # MERGEを使用して状態をUPSERT

            # 挿入用データの準備
            rows_to_insert = [
                {
                    "race_code_uma_jvd": u["race_code_uma_jvd"],
                    "content_hash": u["content_hash"],
                    "exported_at": datetime.datetime.now().isoformat()
                }
                for u in state_updates
            ]

            # 1. 一時テーブルへのロード
            job_config = bigquery.LoadJobConfig(
                write_disposition="WRITE_TRUNCATE",
                schema=[
                    bigquery.SchemaField("race_code_uma_jvd", "STRING"),
                    bigquery.SchemaField("content_hash", "STRING"),
                    bigquery.SchemaField("exported_at", "TIMESTAMP"),
                ]
            )
            temp_table_id = f"{PROJECT_ID}.{DATASET_ID}.temp_race_uma_details_state_updates"
            load_job = bq_client.load_table_from_json(rows_to_insert, temp_table_id, job_config=job_config)
            load_job.result() # 待機

            # 2. マージ実行
            merge_query = f"""
                MERGE `{PROJECT_ID}.{DATASET_ID}.{STATE_TABLE_NAME}` T
                USING `{temp_table_id}` S
                ON T.race_code_uma_jvd = S.race_code_uma_jvd
                WHEN MATCHED THEN
                  UPDATE SET content_hash = S.content_hash, exported_at = S.exported_at
                WHEN NOT MATCHED THEN
                  INSERT (race_code_uma_jvd, content_hash, exported_at)
                  VALUES (race_code_uma_jvd, content_hash, exported_at)
            """
            bq_client.query(merge_query).result()
            logger.info("状態管理テーブルが更新されました。")

            # 一時テーブルの削除
            bq_client.delete_table(temp_table_id, not_found_ok=True)

        return f"成功。 {len(updates)} 行をエクスポートしました。", 200

    except Exception as e:
        logger.exception("実行中にエラーが発生しました。")
        return f"内部サーバーエラー: {e}", 500

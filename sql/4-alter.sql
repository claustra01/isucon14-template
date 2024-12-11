-- 良い感じのindex追加
CREATE INDEX idx_chair_locations_chair_id_created_at ON chair_locations (chair_id, created_at);
CREATE INDEX idx_ride_statuses_ride_id_created_at ON ride_statuses (ride_id, created_at);
CREATE INDEX idx_ride_statuses_ride_id_chair_id_status_created_at ON ride_statuses (ride_id, status, created_at);
CREATE INDEX idx_ride_statuses_ride_id_chair_sent_at_created_at ON ride_statuses (ride_id, chair_sent_at, created_at);
CREATE INDEX idx_ride_statuses_ride_id_app_sent_at_created_at ON ride_statuses (ride_id, app_sent_at, created_at);
CREATE INDEX idx_rides_chair_id_created_at ON rides (chair_id, created_at);
CREATE INDEX idx_rides_chair_id_updated_at ON rides (chair_id, updated_at);
CREATE INDEX idx_rides_user_id_created_at ON rides (user_id, created_at);
CREATE INDEX idx_chairs_access_token ON chairs (access_token);
CREATE INDEX idx_coupons_used_by ON coupons (used_by);

-- latest_statusカラムとトリガー追加
ALTER TABLE rides
ADD COLUMN latest_status ENUM ('MATCHING', 'ENROUTE', 'PICKUP', 'CARRYING', 'ARRIVED', 'COMPLETED') NULL COMMENT '最新の状態';

UPDATE rides r
JOIN (
    SELECT ride_id, status
    FROM ride_statuses
    WHERE (ride_id, created_at) IN (
        SELECT ride_id, MAX(created_at)
        FROM ride_statuses
        GROUP BY ride_id
    )
) rs ON r.id = rs.ride_id
SET r.latest_status = rs.status, r.updated_at = r.updated_at;

DELIMITER //
CREATE TRIGGER trigger_rides_update_latest_status
  AFTER INSERT ON ride_statuses
  FOR EACH ROW
  BEGIN
    UPDATE rides
    SET 
      latest_status = NEW.status,
      updated_at = updated_at
    WHERE id = NEW.ride_id;
  END;
//

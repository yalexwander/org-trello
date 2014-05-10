;;; org-trello-server.el --- Server (proxy + webadmin + elnode) facade namespace.
;;; Commentary:
;;; Code:

(defvar *ORGTRELLO-SERVER/DB*   nil         "Database reference to orgtrello-proxy")
(defvar *ORGTRELLO/SERVER-HOST* "localhost" "Proxy host")
(defvar *ORGTRELLO/SERVER-PORT* nil         "Proxy port")
(defvar *ORGTRELLO/SERVER-URL*  nil         "Proxy url")

(defvar *ORGTRELLO/SERVER-DEFAULT-PORT* 9876 "Default proxy port") (setq *ORGTRELLO/SERVER-PORT* *ORGTRELLO/SERVER-DEFAULT-PORT*)

(defun orgtrello-server/--proxy-handler (http-con)
  "Proxy handler."
  (elnode-hostpath-dispatcher http-con (append *ORGTRELLO/QUERY-APP-ROUTES-WEBADMIN* *ORGTRELLO/QUERY-APP-ROUTES-PROXY*)))

(defun orgtrello-server/--start! (port host)
  "Starting the proxy."
  (elnode-start 'orgtrello-server/--proxy-handler :port port :host host)
  (setq elnode--do-error-logging nil))

(defun orgtrello-server/--server-should-be-started-p (nb-org-trello-buffers)
  "Determine if the server should be started or not. Return t if it should, nil otherwise."
  (<= nb-org-trello-buffers 0))

(defun orgtrello-server/--server-should-be-stopped-p (nb-org-trello-buffers)
  "Determine if the server should be stopped. Return t if the server should be, nil otherwise."
  (<= nb-org-trello-buffers 0))

(defun orgtrello-server/start ()
  "Start the server."
  (orgtrello-log/msg *OT/TRACE* "Server starting...")
  ;; initialize the database (if already initialized, keep it the same, otherwise, init it)
  (setq *ORGTRELLO-SERVER/DB* (if *ORGTRELLO-SERVER/DB* *ORGTRELLO-SERVER/DB* (orgtrello-db/init)))
  ;; update with the new port the user possibly changed
  (setq *ORGTRELLO/SERVER-URL* (format "http://%s:%d/proxy" *ORGTRELLO/SERVER-HOST* *ORGTRELLO/SERVER-PORT*))
  ;; Check the number of org-trello buffers to determine if we need to start the server
  (when (orgtrello-server/--server-should-be-started-p (orgtrello-db/nb-buffers *ORGTRELLO-SERVER/DB*))
    ;; start the proxy
    (orgtrello-server/--start! *ORGTRELLO/SERVER-PORT* *ORGTRELLO/SERVER-HOST*)
    ;; and the timer
    (orgtrello-proxy/timer-start))
  (orgtrello-log/msg *OT/TRACE* "Server started!"))

(defun orgtrello-server/stop (&optional force-stop)
  "Stop the server."
  (orgtrello-log/msg *OT/TRACE* "Server stopping...")
  (when (or force-stop (orgtrello-server/--server-should-be-stopped-p (orgtrello-db/nb-buffers *ORGTRELLO-SERVER/DB*)))
    ;; flush the database to disk if we do stop the server
    (orgtrello-db/save! *ORGTRELLO-SERVER/DB*)
    ;; stop the timer
    (orgtrello-proxy/timer-stop)
    ;; then stop the proxy
    (elnode-stop *ORGTRELLO/SERVER-PORT*))
  (orgtrello-log/msg *OT/TRACE* "Server stopped!"))

(defun orgtrello-server/reload ()
  "Reload the proxy server."
  (orgtrello-server/stop 'force-stop-server)
  ;; stop the default port (only useful if the user changed from the default port)
  (elnode-stop *ORGTRELLO/SERVER-DEFAULT-PORT*)
  (orgtrello-server/start))

(orgtrello-log/msg *OT/DEBUG* "org-trello - orgtrello-server loaded!")

(provide 'org-trello-server)
;;; org-trello-server.el ends here

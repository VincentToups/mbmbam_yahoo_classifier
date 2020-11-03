(require [dotdot [chain]])
(require [hy.contrib.loop [loop]])
(import io
        json
        random
        [numpy :as np]
        [pandas :as pd])
(import [sklearn.ensemble [AdaBoostClassifier]]
        [sklearn.manifold [TSNE]]
        [sklearn.tree [DecisionTreeClassifier]]
        [plotnine [*]]
        [scipy [sparse]])

(defn load-json [filename]
  (print (chain "input: {}" (format filename)))
  (with [f (io.open filename "r" :encoding "ascii")]
        (json.load f)))

(defn write-json [exp filename]
  (print (chain "output: {}" (format filename)))
  (with [f (io.open filename :mode "w" :encoding "ascii")]
        (f.write (json.dumps exp :indent 1))))

(setv data (load-json "./derived_data/encoded.json"))
(setv metadata (load-json "./derived_data/encoding-information.json"))

;; Get the largest encoding value
(setv max-encoding
      (max (map (fn [x] (get x 1))
                (chain metadata ["encoding"] (items)))))
;; Each value will be an index, but we won't use --stop-- and --unknown--
;; so the maximum index will  be max-encoding - 2, so we need max-encoding - 1
;; elements


(setv i 0)
(setv train [])
(setv test [])

(for [datum data]
  (setv (chain datum "index") i)
  (setv train_ (< (random.random) 0.95))
  (setv (chain datum "train") train_)
  (chain (if train_ train test)
         (append datum))
  (setv i (+ i 1)))

(setv X_train (sparse.dok_matrix (tuple [(len train) (- max-encoding 1)])))
(setv y_train [])
(setv i 0)
(for [datum train]
  (chain y_train (append (= "experimental" (chain datum "category"))))
  (for [code (chain datum "encoded_question")]
    (when (>= code 2)
      (setv (chain X_train [(tuple
                             [i (- code 2)])]) 1)))
  (setv i (+ i 1)))

(setv X_test (sparse.dok_matrix (tuple [(len test) (- max-encoding 1)])))
(setv y_test [])
(setv i 0)
(for [datum test]
  (chain y_test (append (= "experimental" (chain datum "category"))))
  (for [code (chain datum "encoded_question")]
    (when (>= code 2)
      (setv (chain X_test [(tuple
                            [i (- code 2)])]) 1)))
  (setv i (+ i 1)))

(setv ab (AdaBoostClassifier :n_estimators 70 :base_estimator (DecisionTreeClassifier :max_depth 4)))
(chain ab (fit X_train y_train))
(print (chain "
train acc : {}
test acc  : {}" (format (chain ab (score X_train y_train))
                        (chain ab (score X_test y_test)))))

(setv sorted-by-importance
      (list
       (map (fn [p]
              (tuple [(chain metadata ["decoding"] [(str (get p 0))])
                      (get p 1)]))
            (sorted
             (list
              (zip (+ 2  (cut (- (np.arange max-encoding) 2) 2))
                   (chain ab feature_importances_)))
             :key (fn [p] (- (get p 1)))))))

(write-json sorted-by-importance "./derived_data/feature-importances.json")



;; First step is ginning up the sparse encoding.

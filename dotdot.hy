(defmacro chain [&rest forms]
  (defn same-class-as [item exemplar]
    (= (type item)
       (type exemplar)))
  (defn expression? [item]
    (same-class-as item '(a)))
  (defn list? [item]
    (same-class-as item '[a]))
  (defn string-exp? [item]
    (same-class-as item '""))
  (defn symbol-exp? [item]
    (same-class-as item 'x))
  (defn int-exp? [item]
    (same-class-as item '10))
  (cond
    [(= 1 (len forms)) (first forms)]
    [True
     (setv head (first forms))
     (setv first-index (second forms))
     (setv rest-forms (cut forms 2))
     (cond
       [(expression? first-index)
        (setv method (first first-index))
        (setv args (cut first-index 1))
        `(chain ((. ~head ~method) ~@args)
             ~@rest-forms)]
       [(symbol-exp? first-index)
        `(chain (. ~head ~first-index) ~@rest-forms)]
       [(or (string-exp? first-index)
            (int-exp? first-index))
        `(chain (. ~head [~first-index]) ~@rest-forms)]
       [True `(chain (. ~head ~first-index) ~@rest-forms)])]))

{application,mime,
             [{modules,['Elixir.MIME']},
              {compile_env,[{mime,[extensions],error},
                            {mime,[suffixes],error},
                            {mime,[types],error}]},
              {optional_applications,[]},
              {applications,[kernel,stdlib,elixir,logger]},
              {description,"A MIME type module for Elixir"},
              {registered,[]},
              {vsn,"2.0.7"},
              {env,[]}]}.

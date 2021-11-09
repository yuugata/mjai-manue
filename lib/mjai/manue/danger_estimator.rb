# coding: utf-8

require "set"
require "optparse"

require "mjai/pai"
require "mjai/archive"
require "mjai/confidence_interval"


module Mjai
  
  module Manue
    
    
    class DangerEstimator
        
        class Scene
            
            @@feature_names = []
            
            def self.define_feature(name, &block)
              define_method(name, &block)
              @@feature_names.push(name)
            end
            
            def self.feature_names
              return @@feature_names
            end
            
            def initialize(params)
              
              if params[:game]
                params = params.dup()
                # Adds params[:dapai] because the game object points to the scene after the dapai.
                params[:tehais] = params[:me].tehais + (params[:dapai] ? [params[:dapai]] : [])
                params[:anpais] = params[:reacher].anpais
                params[:doras] = params[:game].doras
                params[:bakaze] = params[:game].bakaze
                params[:reacher_kaze] = params[:reacher].jikaze
                params[:visible] = []
                params[:visible] += params[:game].dora_markers
                params[:visible] += params[:me].tehais
                for player in params[:game].players
                  params[:visible] += player.ho + player.furos.map(){ |f| f.pais }.flatten()
                end
              end
              
              prereach_sutehais = params[:prereach_sutehais]
              @tehai_set = to_pai_set(params[:tehais])
              @anpai_set = to_pai_set(params[:anpais])
              @visible_set = to_pai_set(params[:visible])
              @dora_set = to_pai_set(params[:doras])
              @bakaze = params[:bakaze]
              @reacher_kaze = params[:reacher_kaze]
              
              @prereach_sutehai_set = to_pai_set(prereach_sutehais)
              @early_sutehai_set = to_pai_set(prereach_sutehais[0...(prereach_sutehais.size / 2)])
              @late_sutehai_set = to_pai_set(prereach_sutehais[(prereach_sutehais.size / 2)..-1])
              # prereach_sutehais can be empty in unit tests.
              @reach_pai = prereach_sutehais[-1] ? prereach_sutehais[-1].remove_red() : nil
              
              @candidates = @tehai_set.keys.select(){ |pai| !@anpai_set.has_key?(pai) }
              
            end
            
            attr_reader(:candidates)
            
            def to_pai_set(pais)
              pai_set = Hash.new(0)
              for pai in pais
                pai_set[pai.remove_red()] += 1
              end
              return pai_set
            end
            
            # pai is without red.
            # Use bit vector to make match? faster.
            def feature_vector(pai)
              return DangerEstimator.bool_array_to_bit_vector(
                  @@feature_names.map(){ |s| __send__(s, pai) })
            end
            
            def anpai?(pai)
              return @anpai_set.has_key?(pai.remove_red())
            end
            
            define_feature("tsupai") do |pai|
              return pai.type == "t"
            end
            
            # 表筋 or 中筋
            define_feature("suji") do |pai|
              return suji_of(pai, @anpai_set)
            end
            
            # 片筋 or 筋
            define_feature("weak_suji") do |pai|
              return weak_suji_of(pai, @anpai_set)
            end
            
            # リーチ牌の筋。1pリーチに対する4pなども含む。
            define_feature("reach_suji") do |pai|
              return weak_suji_of(pai, to_pai_set([@reach_pai]))
            end
            
            define_feature("prereach_suji") do |pai|
              return suji_of(pai, @prereach_sutehai_set)
            end
            
            # http://ja.wikipedia.org/wiki/%E7%AD%8B_(%E9%BA%BB%E9%9B%80)#.E8.A3.8F.E3.82.B9.E3.82.B8
            define_feature("urasuji") do |pai|
              return urasuji_of(pai, @prereach_sutehai_set)
            end
            
            define_feature("early_urasuji") do |pai|
              return urasuji_of(pai, @early_sutehai_set)
            end
            
            define_feature("reach_urasuji") do |pai|
              return urasuji_of(pai, to_pai_set([@reach_pai]))
            end
            
            define_feature("urasuji_of_5") do |pai|
              return urasuji_of(pai, @prereach_sutehai_set.select(){ |pai, f| pai.type != "t" && pai.number == 5 })
            end
            
            # http://ja.wikipedia.org/wiki/%E7%AD%8B_(%E9%BA%BB%E9%9B%80)#.E9.96.93.E5.9B.9B.E9.96.93
            define_feature("aida4ken") do |pai|
              if pai.type == "t" || pai.type == "m"
                return false
              else
                return ((2..5).include?(pai.number) &&
                      @prereach_sutehai_set.has_key?(Pai.new(pai.type, pai.number - 1)) &&
                      @prereach_sutehai_set.has_key?(Pai.new(pai.type, pai.number + 4))) ||
                    ((5..8).include?(pai.number) &&
                      @prereach_sutehai_set.has_key?(Pai.new(pai.type, pai.number - 4)) &&
                      @prereach_sutehai_set.has_key?(Pai.new(pai.type, pai.number + 1)))
              end
            end
            
            # http://ja.wikipedia.org/wiki/%E7%AD%8B_(%E9%BA%BB%E9%9B%80)#.E3.81.BE.E3.81.9F.E3.81.8E.E3.82.B9.E3.82.B8
            define_feature("matagisuji") do |pai|
              return matagisuji_of(pai, @prereach_sutehai_set)
            end
            
            define_feature("early_matagisuji") do |pai|
              return matagisuji_of(pai, @early_sutehai_set)
            end
            
            define_feature("late_matagisuji") do |pai|
              return matagisuji_of(pai, @late_sutehai_set)
            end
            
            define_feature("reach_matagisuji") do |pai|
              return matagisuji_of(pai, to_pai_set([@reach_pai]))
            end
            
            # http://ja.wikipedia.org/wiki/%E7%AD%8B_(%E9%BA%BB%E9%9B%80)#.E7.96.9D.E6.B0.97.E3.82.B9.E3.82.B8
            define_feature("senkisuji") do |pai|
              return senkisuji_of(pai, @prereach_sutehai_set)
            end
            
            define_feature("early_senkisuji") do |pai|
              return senkisuji_of(pai, @early_sutehai_set)
            end
            
            define_feature("outer_prereach_sutehai") do |pai|
              return outer(pai, @prereach_sutehai_set)
            end
            
            define_feature("outer_early_sutehai") do |pai|
              return outer(pai, @early_sutehai_set)
            end
            
            (0..3).each() do |n|
              define_feature("chances<=#{n}") do |pai|
                return n_chance_or_less(pai, n)
              end
            end
            
            # 自分から見て何枚見えているか。自分の手牌も含む。出そうとしている牌自身は含まない。
            (1..3).each() do |i|
              define_feature("visible>=%d" % i) do |pai|
                # i + 出そうとしている牌
                return visible_n_or_more(pai, i + 1)
              end
            end
            
            # その牌の筋の牌のうち1つがi枚以下しか見えていない。
            # その牌自身はカウントしない。
            # 5pの場合は「2pと8pのどちらかがi枚以下しか見えていない」であり、「2pと8pが合計でi枚以下しか見えていない」ではない。
            (0..3).each() do |i|
              define_feature("suji_visible<=#{i}") do |pai|
                if pai.type == "t" || pai.type == "m"
                  return false
                else
                  return get_suji_numbers(pai).any?(){ |n| !visible_n_or_more(Pai.new(pai.type, n), i + 1) }
                end
              end
            end
            
            (2..5).each() do |i|
              define_feature("%d<=n<=%d" % [i, 10 - i]) do |pai|
                return num_n_or_inner(pai, i)
              end
            end
            
            define_feature("dora") do |pai|
              return @dora_set.has_key?(pai)
            end
            
            define_feature("dora_suji") do |pai|
              return weak_suji_of(pai, @dora_set)
            end
            
            define_feature("dora_matagi") do |pai|
              return matagisuji_of(pai, @dora_set)
            end
            
            (2..4).each() do |i|
              define_feature("in_tehais>=#{i}") do |pai|
                return @tehai_set[pai] >= i
              end
            end
            
            # その牌の筋の牌のうち1つをi枚以上持っている。
            # その牌自身はカウントしない。
            # 5pの場合は「2pと8pのどちらかをi枚以上持っている」であり、「2pと8pを合計i枚以上持っている」ではない。
            (1..4).each() do |i|
              define_feature("suji_in_tehais>=#{i}") do |pai|
                if pai.type == "t" || pai.type == "m"
                  return false
                else
                  return get_suji_numbers(pai).any?(){ |n| @tehai_set[Pai.new(pai.type, n)] >= i }
                end
              end
            end
            
            (1..2).each() do |i|
              (1..(i * 2)).each() do |j|
                define_feature("+-#{i}_in_prereach_sutehais>=#{j}") do |pai|
                  n_or_more_of_neighbors_in_prereach_sutehais(pai, j, i)
                end
              end
            end
            
            (1..2).each() do |i|
              define_feature("#{i}_outer_prereach_sutehai") do |pai|
                n_outer_prereach_sutehai(pai, i)
              end
            end
            
            (1..2).each() do |i|
              define_feature("#{i}_inner_prereach_sutehai") do |pai|
                n_outer_prereach_sutehai(pai, -i)
              end
            end
            
            (1..8).each() do |i|
              define_feature("same_type_in_prereach>=#{i}") do |pai|
                if pai.type == "t" || pai.type == "m"
                  return false
                else
                  num_same_type = (1..9).
                      select(){ |n| @prereach_sutehai_set.has_key?(Pai.new(pai.type, n)) }.
                      size
                  return num_same_type >= i
                end
              end
            end
            
            define_feature("fanpai") do |pai|
              return fanpai_fansu(pai) >= 1
            end
            
            define_feature("ryenfonpai") do |pai|
              return fanpai_fansu(pai) >= 2
            end
            
            define_feature("sangenpai") do |pai|
              return pai.type == "t" && pai.number >= 5
            end
            
            define_feature("fonpai") do |pai|
              return pai.type == "t" && pai.number < 5
            end
            
            define_feature("bakaze") do |pai|
              return pai == @bakaze
            end
            
            define_feature("jikaze") do |pai|
              return pai == @reacher_kaze
            end
            
            def n_outer_prereach_sutehai(pai, n)
              if pai.type == "t" || pai.type == "m"
                return false
              elsif pai.number < 6 - n || pai.number > 4 + n
                n_inner_pai = Pai.new(pai.type, pai.number < 5 ? pai.number + n : pai.number - n)
                return @prereach_sutehai_set.include?(n_inner_pai)
              else
                return false
              end
            end
            
            def n_or_more_of_neighbors_in_prereach_sutehais(pai, n, neighbor_distance)
              if pai.type == "t" || pai.type == "m"
                return false
              else
                num_neighbors =
                    ((pai.number - neighbor_distance)..(pai.number + neighbor_distance)).
                    select(){ |n| @prereach_sutehai_set.has_key?(Pai.new(pai.type, n)) }.
                    size
                return num_neighbors >= n
              end
            end
            
            def suji_of(pai, target_pai_set)
              if pai.type == "t" || pai.type == "m"
                return false
              else
                return get_suji_numbers(pai).all?(){ |n| target_pai_set.has_key?(Pai.new(pai.type, n)) }            
              end
            end
            
            def weak_suji_of(pai, target_pai_set)
              if pai.type == "t" || pai.type == "m"
                return false
              else
                return get_suji_numbers(pai).any?(){ |n| target_pai_set.has_key?(Pai.new(pai.type, n)) }
              end
            end
            
            def get_suji_numbers(pai)
              return [pai.number - 3, pai.number + 3].select(){ |n| (1..9).include?(n) }
            end
            
            # Uses the first pai to represent the suji. e.g. 1p for 14p suji
            def get_possible_sujis(pai)
              if pai.type == "t" || pai.type == "m"
                return []
              else
                ns = [pai.number - 3, pai.number].select() do |n|
                  [n, n + 3].all?(){ |m| (1..9).include?(m) && !@anpai_set.include?(Pai.new(pai.type, m)) }
                end
                return ns.map(){ |n| Pai.new(pai.type, n) }
              end
            end
            
            def n_chance_or_less(pai, n)
              if pai.type == "t" || (4..6).include?(pai.number) || pai.type == "m"
                return false
              else
                return (1..2).any?() do |i|
                  kabe_pai = Pai.new(pai.type, pai.number + (pai.number < 5 ? i : -i))
                  @visible_set[kabe_pai] >= 4 - n
                end
              end
            end
            
            def num_n_or_inner(pai, n)
              return pai.type != "t" && pai.number >= n && pai.number <= 10 - n && pai.type != "m"
            end
            
            def visible_n_or_more(pai, n)
              return @visible_set[pai] >= n
            end
            
            def urasuji_of(pai, target_pai_set)
              if pai.type == "t" || pai.type == "m"
                return false
              else
                sujis = get_possible_sujis(pai)
                return sujis.any?(){ |s| target_pai_set.has_key?(s.next(-1)) || target_pai_set.has_key?(s.next(4)) }
              end
            end
            
            def senkisuji_of(pai, target_pai_set)
              if pai.type == "t" || pai.type == "m"
                return false
              else
                sujis = get_possible_sujis(pai)
                return sujis.any?(){ |s| target_pai_set.has_key?(s.next(-2)) || target_pai_set.has_key?(s.next(5)) }
              end
            end
            
            def matagisuji_of(pai, target_pai_set)
              if pai.type == "t" || pai.type == "m"
                return false
              else
                sujis = get_possible_sujis(pai)
                return sujis.any?(){ |s| target_pai_set.has_key?(s.next(1)) || target_pai_set.has_key?(s.next(2)) }
              end
            end
            
            def outer(pai, target_pai_set)
              if pai.type == "t" || pai.number == 5 || pai.type == "m"
                return false
              else
                inner_numbers = pai.number < 5 ? ((pai.number + 1)..5) : (5..(pai.number - 1))
                return inner_numbers.any?(){ |n| target_pai_set.has_key?(Pai.new(pai.type, n)) }
              end
            end
            
            def fanpai_fansu(pai)
              if pai.type == "t" && pai.number >= 5
                return 1
              else
                return (pai == @bakaze ? 1 : 0) + (pai == @reacher_kaze ? 1 : 0)
              end
            end
            
        end

        StoredKyoku = Struct.new(:scenes)
        StoredScene = Struct.new(:candidates)
        DecisionNode = Struct.new(
            :average_prob, :conf_interval, :num_samples, :feature_name, :positive, :negative)
        
        class DecisionTree
            
            def initialize(path)
              @root = open(path, "rb"){ |f| Marshal.load(f) }
            end
            
            def estimate_prob(scene, pai)
              feature_vector = scene.feature_vector(pai.remove_red())
              p [pai, DangerEstimator.feature_vector_to_str(feature_vector)]
              node = @root
              while node.feature_name
                if DangerEstimator.get_feature_value(feature_vector, node.feature_name)
                  node = node.positive
                else
                  node = node.negative
                end
              end
              return node.average_prob
            end
            
        end
        
        def initialize()
          @min_gap = 0.0
        end
        
        attr_accessor(:verbose)
        attr_accessor(:min_gap)
        
        def extract_features_from_files(input_paths, output_path, listener = nil)
          require "with_progress"
          $stderr.puts("%d files." % input_paths.size)
          open(output_path, "wb") do |f|
            meta_data = {
              :feature_names => Scene.feature_names,
            }
            Marshal.dump(meta_data, f)
            @stored_kyokus = []
            input_paths.enum_for(:each_with_progress).each_with_index() do |path, i|
              if i % 100 == 0 && i > 0
                Marshal.dump(@stored_kyokus, f)
                @stored_kyokus.clear()
              end
              extract_features_from_file(path, listener)
            end
            Marshal.dump(@stored_kyokus, f)
          end
        end
        
        def extract_features_from_file(input_path, listener)
          begin
            stored_kyoku = nil
            reacher = nil
            waited = nil
            prereach_sutehais = nil
            skip = false
            archive = Archive.load(input_path)
            archive.each_action() do |action|
              archive.dump_action(action) if self.verbose
              case action.type
                
                when :start_kyoku
                  stored_kyoku = StoredKyoku.new([])
                  reacher = nil
                  skip = false
                
                when :end_kyoku
                  next if skip
                  raise("should not happen") if !stored_kyoku
                  @stored_kyokus.push(stored_kyoku)
                  stored_kyoku = nil
                
                when :reach_accepted
                  if ["ASAPIN", "（≧▽≦）"].include?(action.actor.name) || reacher
                    skip = true
                  end
                  next if skip
                  reacher = action.actor
                  waited = TenpaiAnalysis.new(action.actor.tehais).waited_pais
                  prereach_sutehais = reacher.sutehais.dup()
                
                when :dahai
                  next if skip || !reacher || action.actor.reach?
                  scene = Scene.new({
                      :game => archive,
                      :me => action.actor,
                      :dapai => action.pai,
                      :reacher => reacher,
                      :prereach_sutehais => prereach_sutehais,
                  })
                  stored_scene = StoredScene.new([])
                  #p [:candidates, action.actor, reacher, scene.candidates.join(" ")]
                  puts("reacher: %d" % reacher.id) if self.verbose
                  candidates = []
                  for pai in scene.candidates
                    hit = waited.include?(pai)
                    feature_vector = scene.feature_vector(pai)
                    stored_scene.candidates.push([feature_vector, hit])
                    candidates.push({
                        :pai => pai,
                        :hit => hit,
                        :feature_vector => feature_vector,
                    })
                    if self.verbose
                      puts("candidate %s: hit=%d, %s" % [
                          pai,
                          hit ? 1 : 0,
                          DangerEstimator.feature_vector_to_str(feature_vector)])
                    end
                  end
                  stored_kyoku.scenes.push(stored_scene)
                  if listener
                    listener.on_dahai({
                        :game => archive,
                        :action => action,
                        :reacher => reacher,
                        :candidates => candidates,
                    })
                  end
                  
              end
            end
          rescue Exception
            $stderr.puts("at #{input_path}")
            raise()
          end
        end
        
        def calculate_single_probabilities(features_path)
          criteria = Scene.feature_names.map(){ |s| [{s => false}, {s => true}] }.flatten()
          calculate_probabilities(features_path, criteria)
        end
        
        def generate_decision_tree(features_path, base_criterion = {}, base_node = nil, root = nil)
          p [:generate_decision_tree, base_criterion]
          targets = {}
          criteria = []
          criteria.push(base_criterion) if !base_node
          for name in Scene.feature_names
            next if base_criterion.has_key?(name)
            negative_criterion = base_criterion.merge({name => false})
            positive_criterion = base_criterion.merge({name => true})
            targets[name] = [negative_criterion, positive_criterion]
            criteria.push(negative_criterion, positive_criterion)
          end
          node_map = calculate_probabilities(features_path, criteria)
          base_node = node_map[base_criterion] if !base_node
          root = base_node if !root
          gaps = {}
          for name, (negative_criterion, positive_criterion) in targets
            negative = node_map[negative_criterion]
            positive = node_map[positive_criterion]
            next if !positive || !negative
            if positive.average_prob >= negative.average_prob
              gap = positive.conf_interval[0] - negative.conf_interval[1]
            else
              gap = negative.conf_interval[0] - positive.conf_interval[1]
            end
            p [name, gap]
            gaps[name] = gap if gap > @min_gap
          end
          max_name = gaps.keys.max_by(){ |s| gaps[s] }
          p [:max_name, max_name]
          if max_name
            (negative_criterion, positive_criterion) = targets[max_name]
            base_node.feature_name = max_name
            base_node.negative = node_map[negative_criterion]
            base_node.positive = node_map[positive_criterion]
            render_decision_tree(root, "all")
            generate_decision_tree(features_path, negative_criterion, base_node.negative, root)
            generate_decision_tree(features_path, positive_criterion, base_node.positive, root)
          end
          return base_node
        end
        
        def render_decision_tree(node, label, indent = 0)
          puts("%s%s : %.2f [%.2f, %.2f] (%d samples)" %
              ["  " * indent,
               label,
               node.average_prob * 100.0,
               node.conf_interval[0] * 100.0,
               node.conf_interval[1] * 100.0,
               node.num_samples])
          if node.feature_name
            for value, child in [[false, node.negative], [true, node.positive]].
                sort_by(){ |v, c| c.average_prob }
              render_decision_tree(child, "%s = %p" % [node.feature_name, value], indent + 1)
            end
          end
        end

        def node_to_hash(node)
          if node
            return {
                "average_prob" => node.average_prob,
                "conf_interval" => node.conf_interval,
                "num_samples" => node.num_samples,
                "feature_name" => node.feature_name,
                "negative" => node_to_hash(node.negative),
                "positive" => node_to_hash(node.positive),
            }
          else
            return nil
          end
        end
        
        def calculate_probabilities(features_path, criteria)
          create_kyoku_probs_map(features_path, criteria)
          return aggregate_probabilities(criteria)
        end
        
        def create_kyoku_probs_map(features_path, criteria)
          
          require "with_progress"
          
          @kyoku_probs_map = {}
          
          criterion_masks = {}
          for criterion in criteria
            positive_ary = [false] * Scene.feature_names.size
            negative_ary = [true] * Scene.feature_names.size
            for name, value in criterion
              index = Scene.feature_names.index(name)
              raise("no such feature: %p" % name) if !index
              if value
                positive_ary[index] = true
              else
                negative_ary[index] = false
              end
            end
            criterion_masks[criterion] = [
              DangerEstimator.bool_array_to_bit_vector(positive_ary),
              DangerEstimator.bool_array_to_bit_vector(negative_ary),
            ]
          end
          
          open(features_path, "rb") do |f|
            meta_data = Marshal.load(f)
            if meta_data[:feature_names] != Scene.feature_names
              raise("feature set has been changed")
            end
            f.with_progress() do
              begin
                while true
                  stored_kyokus = Marshal.load(f)
                  for stored_kyoku in stored_kyokus
                    update_metrics_for_kyoku(stored_kyoku, criterion_masks)
                  end
                end
              rescue EOFError
              end
            end
          end
          
        end
        
        def aggregate_probabilities(criteria)
          result = {}
          for criterion in criteria
            kyoku_probs = @kyoku_probs_map[criterion.object_id]
            next if !kyoku_probs
            result[criterion] = node = DecisionNode.new(
                kyoku_probs.inject(:+) / kyoku_probs.size,
                ConfidenceInterval.calculate(kyoku_probs, :min => 0.0, :max => 1.0),
                kyoku_probs.size)
            print("%p\n  %.2f [%.2f, %.2f] (%d samples)\n\n" %
                [criterion,
                 node.average_prob * 100.0,
                 node.conf_interval[0] * 100.0,
                 node.conf_interval[1] * 100.0,
                 node.num_samples])
          end
          return result
        end
        
        def update_metrics_for_kyoku(stored_kyoku, criterion_masks)
          scene_prob_sums = Hash.new(0.0)
          scene_counts = Hash.new(0)
          for stored_scene in stored_kyoku.scenes
            pai_freqs = {}
            for feature_vector, hit in stored_scene.candidates
              for criterion, (positive_mask, negative_mask) in criterion_masks
                if match?(feature_vector, positive_mask, negative_mask)
                  # Uses object_id as key for efficiency.
                  pai_freqs[criterion.object_id] ||= Hash.new(0)
                  pai_freqs[criterion.object_id][hit] += 1
                end
              end
              #p [pai, hit, feature_vector]
            end
            for criterion_id, freqs in pai_freqs
              scene_prob = freqs[true].to_f() / (freqs[false] + freqs[true])
              #p [:scene_prob, criterion, scene_prob]
              scene_prob_sums[criterion_id] += scene_prob
              scene_counts[criterion_id] += 1
            end
          end
          for criterion_id, count in scene_counts
            kyoku_prob = scene_prob_sums[criterion_id] / count
            #p [:kyoku_prob, criterion, kyoku_prob]
            @kyoku_probs_map[criterion_id] ||= []
            @kyoku_probs_map[criterion_id].push(kyoku_prob)
          end
        end
        
        def match?(feature_vector, positive_mask, negative_mask)
          return (feature_vector & positive_mask) == positive_mask &&
              (feature_vector | negative_mask) == negative_mask
        end
        
        def self.bool_array_to_bit_vector(bool_array)
          vector = 0
          bool_array.reverse_each() do |value|
            vector <<= 1
            vector |= 1 if value
          end
          return vector
        end

        def self.feature_vector_to_str(feature_vector)
          return (0...Scene.feature_names.size).select(){ |i| feature_vector[i] != 0 }.
              map(){ |i| Scene.feature_names[i] }.join(" ")
        end
        
        def self.get_feature_value(feature_vector, feature_name)
          return feature_vector[Scene.feature_names.index(feature_name)] != 0
        end
        
    end
    
    
  end
  
end


# For compatibility.
# TODO Remove this.
DecisionNode = Mjai::Manue::DangerEstimator::DecisionNode

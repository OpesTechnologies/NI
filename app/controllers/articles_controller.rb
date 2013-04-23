class ArticlesController < ApplicationController
    include ArticlesHelper
	# Cancan authorisation
  	load_and_authorize_resource

    def strip_tags(string)
        ActionController::Base.helpers.strip_tags(string)
    end

    rescue_from CanCan::AccessDenied do |exception|
        redirect_to new_issue_purchase_path(@article.issue), :alert => "You need to purchase this issue or subscribe to read this article."
    end

    def search
        @articles = Article.search(params, current_user.try(:admin?))
        # if params[:query].present?
        #     @articles = Article.search(params[:query], load: true, :page => params[:page], :per_page => Settings.article_pagination)
        # else
        #     @articles = Article.order("publication").reverse_order.page(params[:page]).per(Settings.article_pagination)
        # end
        # @articles = Article.search(params)
        # @articles = Article.all

        # Set meta tags
        set_meta_tags :title => "Search for an article",
                      :description => "Find an article by keyword from the New Internationalist magazine digital archive.",
                      :keywords => "new, internationalist, magazine, digital, edition, search",
                      :canonical => search_url,
                      :open_graph => {
                        :title => "Search for an article",
                        :description => "Find an article by keyword from the New Internationalist magazine digital archive.",
                        #:type  => :magazine,
                        :url   => search_url,
                        :site_name => "New Internationalist Magazine Digital Edition"
                      }
    end

    def import
        @article = Article.find(params[:article_id])
        @article.issue.import_stories_from_bricolage([@article.story_id])
        redirect_to issue_article_path(@article.issue,@article)
    end

    def import_images
        @article = Article.find(params[:article_id])
        @article.import_media_from_bricolage(force: true)
        redirect_to issue_article_path(@article.issue,@article)
    end

  	def index
  		@issue = Issue.find(params[:issue_id])
  		@article = Article.find(:all)
        # @article = Article.order("created_at").page(params[:page]).per(2).search(params)
  	end

  	def new
        @issue = Issue.find(params[:issue_id])
        @article = @issue.articles.build
    end

    def create
        @issue = Issue.find(params[:issue_id])

        # HACK: assign_nested_attributes_for chokes accepting categories_attributes for a yet-to-be-created article
        saved_article_params = params[:article]
        extracted_categories_attributes = params[:article].try(:extract!,:categories_attributes)
        @article = @issue.articles.create(params[:article])
        # HACK: strip out id's so that categories_attributes= pre-emptively associates these categories with the article before
        # handing it to assign_nested_attributes_for
        extracted_categories_attributes.try(:fetch,:categories_attributes).try(:values).try(:each) do |v|
         v.delete(:id)
         v.delete("id")  
        end 
        # Added this check to be able to create an article without a category
        if not extracted_categories_attributes.try(:fetch,:categories_attributes).nil?
            @article.update_attributes(extracted_categories_attributes)
        end
        
        respond_to do |format|
            if @article.save
                format.html { redirect_to issue_path(@issue), notice: 'Article was successfully created.' }
                format.json { render json: @article, status: :created, location: @article }
            else
                format.html { render action: "new", notice: "Uh oh, couldn't create your article, sorry!" }
                format.json { render json: @article.errors, status: :unprocessable_entity }
            end
        end
    end

    def update
    	@issue = Issue.find(params[:issue_id])
    	@article = Article.find(params[:id])

    	respond_to do |format|
	      if @article.update_attributes(params[:article])
	        format.html { redirect_to issue_article_path, notice: 'Article was successfully updated.' }
	        format.json { head :no_content }
	      else
	        format.html { render action: "edit" }
	        format.json { render json: @article.errors, status: :unprocessable_entity }
	      end
	    end
    end

    def destroy
    	@issue = Issue.find(params[:issue_id])
    	@article = Article.find(params[:id])
    	@article.destroy

    	respond_to do |format|
	      format.html { redirect_to issue_path(@issue) }
	      format.json { head :no_content }
	    end
	end

    def show
    	#@issue = Issue.find(params[:issue_id])
    	@article = Article.find(params[:id])
        @issue = Issue.find(@article.issue_id)
        #@article.is_valid_guest_pass(params[:utm_source])
        @newimage = Image.new
        @letters = @article.categories.select{|c| c.name.include?("/letters/")}
        # Push the single top image to the right for these categories
        @image_top_right = @article.categories.select{|c| 
            c.name.include?("/letters-from/") or 
            c.name.include?("/sections/agenda/") or
            c.name.include?("/image-top-right/") or 
            c.name.include?("/columns/media/")
        }
        # Display the :sixhundred version for these cartoons
        @cartoon = @article.categories.select{|c| 
            c.name.include?("/columns/polyp/") or 
            c.name.include?("/columns/only-planet/") or
            c.name.include?("/columns/exposure/") or
            c.name.include?("/columns/scratchy-lines/") or
            c.name.include?("/columns/open-window/") or
            c.name.include?("/columns/cartoon/")
        }
        if not @cartoon.empty?
            @image_url_string = :sixhundred
            @image_css_string = " article-image-cartoon"
        elsif not @image_top_right.empty?
            @image_url_string = :threehundred
            @image_css_string = " article-image-top-right article-image"
        else
            @image_url_string = :threehundred
            @image_css_string = ""
        end
        #@images = @article.images.all
        # @article.source_to_body(:debug => current_user.try(:admin?))

        article_category_themes = @article.categories.each.select{|c| c.name.include?("/themes/")}
        # logger.info article_category_themes
        @related_articles = []
        article_category_themes.each do |category| 
            @related_articles += category.articles
        end
        @related_articles -= [@article]
        @related_articles = @related_articles.uniq

        # Set meta tags
        set_meta_tags :title => @article.title,
                      :description => @article.teaser,
                      :keywords => "new, internationalist, magazine, digital, edition, #{@article.title}",
                      :canonical => issue_article_url(@issue, @article),
                      :open_graph => {
                        :title => @article.title,
                        :description => strip_tags(@article.teaser),
                        #:type  => :magazine,
                        :url   => issue_article_url(@issue, @article),
                        :image => @article.try(:images).try(:first).try(:data).to_s,
                        :site_name => "New Internationalist Magazine Digital Edition"
                      }
    end

    def edit
        
    	@issue = Issue.find(params[:issue_id])
    	@article = Article.find(params[:id])
        # Moved to _form.html.erb
        # if @article.body.blank?
        #     @article.body = source_to_body(@article, :debug => current_user.try(:admin?))
        # end
    end

end
